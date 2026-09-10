import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/providers/image_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../core/settings/platform_paths.dart';
import '../../core/plugins/plugin_context.dart';
import '../../models/job.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class GoogleGeminiImageProvider extends ImageProvider {
  final PluginContext context;
  final Map<String, ExecutionResult> _results = {};
  final List<String> _cancelledJobs = [];
  final http.Client _client;

  GoogleGeminiImageProvider(this.context, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => "gemini_image";

  @override
  String get name => "Google Gemini (Cloud)";

  @override
  bool get available => context.appSettings.geminiImageKey.isNotEmpty;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final prompt = request.input;
    final apiKey = context.appSettings.geminiImageKey;
    final modelName = context.appSettings.geminiImageModel;
    final aspectRatio = context.appSettings.geminiImageAspectRatio;
    final resolution = context.appSettings.geminiImageResolution;

    if (apiKey.isEmpty) {
      throw Exception("Google Gemini API key is missing");
    }

    final jobId = const Uuid().v4();
    final job = Job(
      id: jobId,
      providerId: id,
      type: "image",
      status: JobStatus.queued,
      metadata: {"prompt": prompt},
    );

    if (_cancelledJobs.contains(jobId)) {
      job.transitionTo(JobStatus.cancelled);
      job.result = "Job cancelled by user";
      _results[jobId] = ExecutionResult.failure(
        JobError(code: 'cancelled', message: 'Job cancelled by user'),
      );
      _cancelledJobs.remove(jobId);
      return job;
    }

    _generateImage(job, prompt, apiKey, modelName, aspectRatio, resolution);

    return job;
  }

  Future<void> _generateImage(
    Job job,
    String prompt,
    String apiKey,
    String modelName,
    String aspectRatio,
    String resolution,
  ) async {
    final jobId = job.id;
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount <= maxRetries) {
      try {
        if (_cancelledJobs.contains(jobId)) {
          throw Exception("Cancelled by user");
        }

        final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent",
        );

        final requestBody = jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {
              "aspectRatio": aspectRatio,
              // "imageSize": resolution, // Optional depending on model support
            },
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
          throw Exception("Cancelled by user");
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data["candidates"] != null &&
              data["candidates"].isNotEmpty &&
              data["candidates"][0]["content"] != null &&
              data["candidates"][0]["content"]["parts"] != null &&
              data["candidates"][0]["content"]["parts"].isNotEmpty) {
            final parts = data["candidates"][0]["content"]["parts"] as List;
            final imagePart = parts.firstWhere(
              (p) => p["inlineData"] != null,
              orElse: () => null,
            );

            if (imagePart != null) {
              final inlineData = imagePart["inlineData"];
              final mimeType = inlineData["mimeType"] ?? "image/jpeg";
              final base64String = inlineData["data"];
              final imageBytes = base64Decode(base64String);

              final ext = mimeType.contains("png") ? "png" : "jpg";
              final outputDir = PlatformPaths.instance.getJobOutputPath(jobId);
              final file = File(p.join(outputDir, "gemini_img_$jobId.$ext"));

              if (!await file.parent.exists()) {
                await file.parent.create(recursive: true);
              }
              await file.writeAsBytes(imageBytes);

              _results[jobId] = ExecutionResult.success(textOutput: file.path);
              job.transitionTo(JobStatus.completed);
              job.progress = 1.0;
              job.result = file.path;
              return; // Success
            } else {
              throw Exception("No image data found in response parts.");
            }
          } else {
            throw Exception("Malformed response: missing candidates or parts.");
          }
        } else if (response.statusCode == 429) {
          if (retryCount < maxRetries) {
            retryCount++;
            await Future.delayed(Duration(seconds: 2 * retryCount));
            continue; // Retry
          } else {
            throw Exception("Rate limit exceeded after $maxRetries retries.");
          }
        } else {
          throw Exception(
            "API Error: ${response.statusCode} - ${response.body}",
          );
        }
      } catch (e) {
        if (_cancelledJobs.contains(jobId)) {
          _results[jobId] = ExecutionResult.failure(
            JobError(code: 'cancelled', message: 'Job cancelled by user'),
          );
          job.transitionTo(JobStatus.cancelled);
          job.error = JobError(
            code: 'cancelled',
            message: 'Job cancelled by user',
          );
          job.metadata["error"] = "Cancelled by user";
        } else {
          _results[jobId] = ExecutionResult.failure(
            JobError(code: 'exception', message: e.toString()),
          );
          job.transitionTo(JobStatus.failed);
          job.error = JobError(code: 'exception', message: e.toString());
          job.metadata["error"] = "Exception: $e";
        }
        return; // Stop on non-retryable error
      }
    }
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    return JobStatusUpdate(status: job.status);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    final result = _results[jobId];
    if (result != null) {
      return result;
    }
    return ExecutionResult.failure(
      JobError(code: 'not_found', message: "Job not found"),
    );
  }

  @override
  Future<void> cancelJob(String jobId) async {
    if (!_cancelledJobs.contains(jobId)) {
      _cancelledJobs.add(jobId);
    }
  }
}
