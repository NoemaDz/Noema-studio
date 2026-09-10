import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/providers/video_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../core/settings/platform_paths.dart';
import '../../core/plugins/plugin_context.dart';
import '../../models/job.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class GoogleGeminiVideoProvider extends VideoProvider {
  final PluginContext context;
  final http.Client _client;
  final List<String> _cancelledJobs = [];
  final Map<String, ExecutionResult> _results = {};

  GoogleGeminiVideoProvider(this.context, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => "gemini_video";

  @override
  String get name => "Google Gemini (Cloud)";

  @override
  bool get available => context.appSettings.geminiVideoKey.isNotEmpty;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final prompt = request.input;
    final imagePath = request.parameters['imagePath'] as String?;
    final apiKey = context.appSettings.geminiVideoKey;
    final modelName = context.appSettings.geminiVideoModel;

    if (apiKey.isEmpty) {
      throw Exception("Google Gemini API key is missing");
    }

    if (imagePath == null || imagePath.isEmpty) {
      throw Exception("Missing imagePath in request parameters");
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception("Image file not found: $imagePath");
    }

    final jobId = const Uuid().v4();
    final job = Job(
      id: jobId,
      providerId: id,
      type: "video",
      status: JobStatus.queued,
      metadata: {
        "prompt": prompt,
        "imagePath": imagePath,
        "modelName": modelName,
      },
    );

    int retryCount = 0;
    const maxRetries = 3;

    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final ext = p.extension(imageFile.path).toLowerCase();
    String mimeType = "image/jpeg";
    if (ext == ".png") {
      mimeType = "image/png";
    } else if (ext == ".webp") {
      mimeType = "image/webp";
    }

    while (retryCount <= maxRetries) {
      try {
        if (_cancelledJobs.contains(jobId)) {
          job.transitionTo(JobStatus.cancelled);
          return job;
        }

        final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/$modelName:predictLongRunning",
        );

        final requestBody = jsonEncode({
          "instances": [
            {
              "prompt": prompt,
              "image": {
                "bytesBase64Encoded": base64Image,
                "mimeType": mimeType,
              },
            },
          ],
          "parameters": {
            "sampleCount": 1,
            "aspectRatio": "16:9",
            "durationSeconds": 8,
          },
        });

        final response = await _client
            .post(
              url,
              headers: {
                "Content-Type": "application/json",
                "x-goog-api-key": apiKey,
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 45));

        if (_cancelledJobs.contains(jobId)) {
          job.transitionTo(JobStatus.cancelled);
          return job;
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["name"] != null) {
            job.metadata["operation_name"] = data["name"];
            return job;
          } else {
            throw Exception("Missing operation name in response");
          }
        } else {
          // Attempt to parse structured error
          String errorMsg = "API Error ${response.statusCode}";
          try {
            final errorData = jsonDecode(response.body);
            if (errorData['error'] != null &&
                errorData['error']['message'] != null) {
              errorMsg = errorData['error']['message'];
            }
          } catch (_) {}

          if (response.statusCode == 429) {
            errorMsg = "Rate limit exceeded";
          }

          throw Exception(errorMsg);
        }
      } catch (e) {
        if (e.toString().contains("Cancelled by user") ||
            _cancelledJobs.contains(jobId)) {
          job.transitionTo(JobStatus.cancelled);
          return job;
        }

        retryCount++;
        if (retryCount > maxRetries) {
          job.error = JobError(
            code: "api_error",
            message: _sanitizeError(
              "Gemini API Error: ${e.toString()}",
              apiKey,
            ),
          );
          job.transitionTo(JobStatus.failed);
          return job;
        }
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }

    return job;
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    if (_cancelledJobs.contains(job.id)) {
      return JobStatusUpdate(status: JobStatus.cancelled);
    }
    if (job.status == JobStatus.failed || job.status == JobStatus.completed) {
      return JobStatusUpdate(status: job.status, error: job.error);
    }

    final operationName = job.metadata["operation_name"];
    if (operationName == null) {
      // Operation hasn't been created yet or failed instantly
      return JobStatusUpdate(status: job.status, error: job.error);
    }

    try {
      final apiKey = context.appSettings.geminiVideoKey;
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/$operationName",
      );

      final response = await _client
          .get(url, headers: {"x-goog-api-key": apiKey})
          .timeout(const Duration(seconds: 30));

      if (_cancelledJobs.contains(job.id)) {
        return JobStatusUpdate(status: JobStatus.cancelled);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool isDone = data["done"] == true;

        if (!isDone) {
          return JobStatusUpdate(status: JobStatus.running);
        }

        if (data["error"] != null) {
          final errorMessage = data["error"]["message"] ?? "Unknown error";
          return JobStatusUpdate(
            status: JobStatus.failed,
            error: JobError(
              code: "operation_failed",
              message: _sanitizeError(errorMessage, apiKey),
            ),
          );
        }

        // Operation is done and successful. Extract the video URI.
        try {
          final responseData = data["response"];
          if (responseData != null) {
            final generatedVideoResponse =
                responseData["generateVideoResponse"];
            if (generatedVideoResponse != null &&
                generatedVideoResponse["generatedSamples"] != null &&
                generatedVideoResponse["generatedSamples"].isNotEmpty) {
              final sample = generatedVideoResponse["generatedSamples"][0];
              if (sample["video"] != null && sample["video"]["uri"] != null) {
                final videoUri = sample["video"]["uri"] as String;
                job.metadata["video_uri"] = videoUri;

                // Download the video immediately
                final videoResponse = await _client
                    .get(
                      Uri.parse(videoUri),
                      headers: {"x-goog-api-key": apiKey},
                    )
                    .timeout(const Duration(minutes: 5));

                if (_cancelledJobs.contains(job.id)) {
                  return JobStatusUpdate(status: JobStatus.cancelled);
                }

                if (videoResponse.statusCode == 200) {
                  final videoBytes = videoResponse.bodyBytes;
                  if (videoBytes.isEmpty) {
                    return JobStatusUpdate(
                      status: JobStatus.failed,
                      error: JobError(
                        code: "download_failed",
                        message: "Downloaded video is empty",
                      ),
                    );
                  }

                  final contentType = videoResponse.headers['content-type'];
                  if (contentType != null &&
                      !contentType.startsWith('video/')) {
                    return JobStatusUpdate(
                      status: JobStatus.failed,
                      error: JobError(
                        code: "download_failed",
                        message:
                            "Downloaded content is not a video: $contentType",
                      ),
                    );
                  }

                  final fileName =
                      'gemini_${job.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
                  final savePath = p.join(
                    PlatformPaths.instance.getJobOutputPath(job.id),
                    fileName,
                  );

                  final file = File(savePath);
                  await file.writeAsBytes(videoBytes);

                  _results[job.id] = ExecutionResult.success(
                    textOutput: savePath,
                  );
                  job.metadata["local_video_path"] = savePath;

                  return JobStatusUpdate(status: JobStatus.completed);
                } else {
                  return JobStatusUpdate(
                    status: JobStatus.failed,
                    error: JobError(
                      code: "download_failed",
                      message:
                          "Failed to download video: HTTP ${videoResponse.statusCode}",
                    ),
                  );
                }
              }
            }
          }
          return JobStatusUpdate(
            status: JobStatus.failed,
            error: JobError(
              code: "missing_video_uri",
              message: "API did not return a valid video URI",
            ),
          );
        } catch (e) {
          return JobStatusUpdate(
            status: JobStatus.failed,
            error: JobError(
              code: "parse_error",
              message: _sanitizeError(
                "Failed to parse API response: ${e.toString()}",
                apiKey,
              ),
            ),
          );
        }
      } else {
        return JobStatusUpdate(
          status: JobStatus.failed,
          error: JobError(
            code: "http_${response.statusCode}",
            message: "Failed to fetch operation status",
          ),
        );
      }
    } catch (e) {
      if (_cancelledJobs.contains(job.id)) {
        return JobStatusUpdate(status: JobStatus.cancelled);
      }
      final apiKey = context.appSettings.geminiVideoKey;
      return JobStatusUpdate(
        status: JobStatus.failed,
        error: JobError(
          code: "network_error",
          message: _sanitizeError(e.toString(), apiKey),
        ),
      );
    }
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    final result = _results[jobId];
    if (result != null) {
      return result;
    }
    // If we are recovering after a restart, try to get from Job metadata if it was saved
    final job = context.jobManager.find(jobId);
    if (job != null) {
      final localPath = job.metadata["local_video_path"];
      if (localPath != null && localPath is String) {
        final file = File(localPath);
        if (await file.exists()) {
          return ExecutionResult.success(textOutput: localPath);
        }
      }
    }
    return ExecutionResult.failure(
      JobError(code: 'not_found', message: "Job result not found"),
    );
  }

  @override
  Future<void> cancelJob(String jobId) async {
    if (!_cancelledJobs.contains(jobId)) {
      _cancelledJobs.add(jobId);
    }
  }

  String _sanitizeError(String message, String apiKey) {
    if (apiKey.isEmpty) return message;
    return message.replaceAll(apiKey, "[REDACTED_API_KEY]");
  }
}
