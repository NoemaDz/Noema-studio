import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../../core/plugins/plugin_context.dart';
import '../../models/job.dart';
import 'package:flutter/services.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../core/retry_policy.dart';
import '../../core/hardware/hardware_service.dart';
import 'comfyui_workflow_adapter.dart';
import 'comfyui_error_parser.dart';
import 'comfyui_preflight_checker.dart';
import '../../core/errors/noema_exception.dart';

class ComfyUIDriver {
  final PluginContext context;
  final Map<String, int> _notFoundCounts = {};

  ComfyUIDriver(this.context);

  String get baseUrl => context.appSettings.comfyUIUrl;

  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) async {
    final bool isVideo = options?["is_video"] == true;
    final String? sourceImagePath = options?["source_image_path"];

    // Check if we have characters for IP-Adapter (only for images)
    final List<dynamic>? characters = options?["characters"];
    // Bypass IP-Adapter on 'fast' profile (low VRAM) to avoid OOM and missing heavy models
    final bool useIpAdapter =
        !isVideo &&
        characters != null &&
        characters.isNotEmpty &&
        context.appSettings.performanceMode != PerformanceProfile.fast;

    // Upload character images first (for IP-Adapter)
    List<dynamic> uploadedCharacters = [];
    if (useIpAdapter) {
      if (characters.length > 3) {
        throw Exception(
          "Maximum 3 characters supported for regional identity per scene. Found ${characters.length}.",
        );
      }
      for (final char in characters) {
        final path = char["imagePath"] as String;
        try {
          final uploadedName = await _uploadImage(path);
          final newChar = Map<String, dynamic>.from(char);
          newChar["imagePath"] = uploadedName;
          uploadedCharacters.add(newChar);
        } catch (e) {
          throw Exception(
            "Character Identity Enforcement Failed: Could not upload character image '$path'. "
            "Ensure the file exists and ComfyUI is reachable. Error: $e",
          );
        }
      }
    }

    String? uploadedVideoSource;
    if (isVideo && sourceImagePath != null) {
      try {
        uploadedVideoSource = await _uploadImage(sourceImagePath);
      } catch (e) {
        throw Exception("Failed to upload source image for video: $e");
      }
    }

    String workflowPath;
    if (isVideo) {
      workflowPath = "assets/workflows/image_to_video_api.json";
    } else {
      if (useIpAdapter) {
        if (characters.length > 1) {
          workflowPath = "assets/workflows/multi_character_api.json";
        } else {
          workflowPath = "assets/workflows/ip_adapter_api.json";
        }
      } else {
        workflowPath = "assets/workflows/text_to_image_api.json";
      }
    }

    String workflow;
    try {
      workflow = await rootBundle.loadString(workflowPath);
    } catch (e) {
      if (useIpAdapter) {
        throw Exception(
          "Character Identity Enforcement Failed: Could not load IP-Adapter workflow ($workflowPath). "
          "Ensure the workflow exists and is registered in pubspec.yaml assets.",
        );
      } else {
        throw Exception("Failed to load generic text_to_image workflow: $e");
      }
    }

    final Map<String, dynamic> json = jsonDecode(workflow);
    final adapter = ComfyUIWorkflowAdapter(json);

    // Semantic Injection
    adapter.setPrompt(prompt);

    if (useIpAdapter) {
      adapter.setCharacterImages(uploadedCharacters);
    }

    // Apply resolution from settings (Must be called AFTER setCharacterImages to apply positions)
    final resolution = context.appSettings.imageResolution;
    adapter.setResolution(resolution);

    // Apply hardware-based performance profile (applies to Image and Video)
    adapter.applyPerformanceProfile(context.appSettings.performanceMode);

    if (isVideo && uploadedVideoSource != null) {
      adapter.setInputByClass('LoadImage', 'image', uploadedVideoSource);
    }

    if (options != null) {
      adapter.applyOptions(options);
    }

    // --- PRE-FLIGHT CHECK ---
    try {
      final preflightChecker = ComfyUIPreflightChecker(baseUrl: baseUrl);
      final preflightResult = await preflightChecker.validateWorkflow(
        adapter.toJson(),
      );

      if (!preflightResult.isOk) {
        final missingStr =
            preflightResult.missingNode ?? preflightResult.missingModel ?? '';
        final isIpAdapterMissing =
            useIpAdapter &&
            (missingStr.contains('IPAdapter') ||
                missingStr.toLowerCase().contains('ipadapter'));

        if (isIpAdapterMissing) {
          debugPrint(
            'ComfyUIDriver Pre-flight: IPAdapter missing (${preflightResult.message}). Falling back to text_to_image.',
          );
          final fallbackWorkflow = await rootBundle.loadString(
            "assets/workflows/text_to_image_api.json",
          );
          final fallbackAdapter = ComfyUIWorkflowAdapter(
            jsonDecode(fallbackWorkflow),
          );
          fallbackAdapter.setPrompt(prompt);
          fallbackAdapter.setResolution(resolution);
          fallbackAdapter.applyPerformanceProfile(
            context.appSettings.performanceMode,
          );
          if (options != null) fallbackAdapter.applyOptions(options);

          return _postPrompt(fallbackAdapter.toJson(), isVideo: isVideo);
        }

        throw NoemaException.fromType(
          NoemaErrorType.modelNotFound,
          "Pre-flight Validation Failed: ${preflightResult.message}",
        );
      }
    } catch (e) {
      if (e is NoemaException && e.type == NoemaErrorType.modelNotFound) {
        rethrow;
      }
      debugPrint(
        "ComfyUIDriver Pre-flight Check warning (proceeding to prompt submission): $e",
      );
    }

    return _postPrompt(adapter.toJson(), isVideo: isVideo);
  }

  Future<Job> _postPrompt(
    Map<String, dynamic> promptJson, {
    required bool isVideo,
  }) async {
    final retryPolicy = const RetryPolicy(maxRetries: 3);

    final response = await retryPolicy.execute(
      () => http
          .post(
            Uri.parse("$baseUrl/prompt"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"prompt": promptJson}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      throw NoemaException.fromType(
        NoemaErrorType.invalidWorkflow,
        "ComfyUI API returned ${response.statusCode}: ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    return Job(
      id: data["prompt_id"],
      providerId: isVideo ? "comfyui_video" : "comfyui",
      type: isVideo ? "video" : "image",
      status: JobStatus.queued,
    );
  }

  Future<String> _uploadImage(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/upload/image"),
    );
    request.files.add(await http.MultipartFile.fromPath('image', filePath));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("ComfyUI API upload returned ${response.statusCode}");
    }

    final body = await response.stream.bytesToString();
    final json = jsonDecode(body);
    return json["name"] as String;
  }

  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    try {
      final queueResponse = await http
          .get(Uri.parse("$baseUrl/queue"))
          .timeout(const Duration(seconds: 5));
      if (queueResponse.statusCode == 200) {
        final queueData = jsonDecode(queueResponse.body);
        final running = queueData["queue_running"] as List;
        final pending = queueData["queue_pending"] as List;

        if (running.any((q) => q[1] == job.id)) {
          return JobStatusUpdate(status: JobStatus.running);
        }
        if (pending.any((q) => q[1] == job.id)) {
          return JobStatusUpdate(status: JobStatus.queued);
        }
      }

      final historyResponse = await http
          .get(Uri.parse("$baseUrl/history/${job.id}"))
          .timeout(const Duration(seconds: 5));
      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        if (historyData.containsKey(job.id)) {
          final jobHistory = historyData[job.id];

          if (jobHistory['status'] != null) {
            final statusStr = jobHistory['status']['status_str'];
            final completed = jobHistory['status']['completed'] == true;

            if (statusStr == 'success' && completed) {
              _notFoundCounts.remove(job.id);
              return JobStatusUpdate(status: JobStatus.completed);
            } else if (statusStr == 'error') {
              _notFoundCounts.remove(job.id);
              String errorMessage;
              try {
                final messages = jobHistory['status']['messages'] as List;
                errorMessage = ComfyUIErrorParser.parseError(messages).toString();
              } catch (e) {
                errorMessage = "Failed to parse ComfyUI error: $e";
              }
              return JobStatusUpdate(
                status: JobStatus.failed, 
                error: JobError(code: 'COMFYUI_ERROR', message: errorMessage)
              );
            }
          }
          // If we reach here, we found the job in history but it's not strictly successful or error.
          // Leave the job state as is (polling).
          return JobStatusUpdate(status: job.status);
        }
      }
    } catch (e) {
      debugPrint("ComfyUIDriver Error in updateJobStatus: $e");
      // Throw exception to allow callers (like JobManager) to retry via RetryPolicy
      // instead of marking the job as permanently failed due to a transient network error.
      throw Exception("Network error while getting job status: $e");
    }

    // If we reach here without exception and it's not found in queue or history, it might be an unknown state.
    // Instead of failing immediately, we allow a few retries because it might be transitioning from queue to history.
    final currentNotFound = (_notFoundCounts[job.id] ?? 0) + 1;
    _notFoundCounts[job.id] = currentNotFound;

    if (currentNotFound > 3) {
      _notFoundCounts.remove(job.id);
      return JobStatusUpdate(
        status: JobStatus.failed, 
        error: JobError(code: 'COMFYUI_NOT_FOUND', message: 'Job not found in ComfyUI queue or history after 3 polls.')
      );
    }
    
    return JobStatusUpdate(status: job.status);
  }

  Future<Asset?> downloadAsset(String jobId) async {
    try {
      final retryPolicy = const RetryPolicy(maxRetries: 3);
      final response = await retryPolicy.execute(
        () => http
            .get(Uri.parse("$baseUrl/history/$jobId"))
            .timeout(const Duration(seconds: 10)),
      );

      if (response.statusCode != 200) {
        debugPrint("ComfyUIDriver: downloadAsset history fetch failed");
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (!data.containsKey(jobId)) {
        throw Exception("HistoryMissing: Job $jobId not found in history data");
      }

      final jobData = data[jobId] as Map<String, dynamic>;
      if (!jobData.containsKey("outputs") || jobData["outputs"] == null) {
        throw Exception("OutputMissing: No outputs found for job $jobId");
      }

      final outputs = jobData["outputs"] as Map<String, dynamic>;

      debugPrint("ComfyUIDriver: Checking outputs... ${outputs.keys}");
      for (final node in outputs.values) {
        if (node is! Map) continue;

        debugPrint("ComfyUIDriver: Node keys: ${node.keys}");

        final images = node["images"] as List?;
        final gifs = node["gifs"] as List?;

        if ((images != null && images.isNotEmpty) ||
            (gifs != null && gifs.isNotEmpty)) {
          final isVideo = gifs != null && gifs.isNotEmpty;
          final filename = isVideo
              ? gifs[0]["filename"]
              : images![0]["filename"];

          final assetUrl = "$baseUrl/view?filename=$filename&type=output";
          debugPrint("ComfyUIDriver: Downloading file from $assetUrl");

          // Actually download the file
          final assetResponse = await retryPolicy.execute(
            () => http
                .get(Uri.parse(assetUrl))
                .timeout(const Duration(seconds: 60)),
          );
          debugPrint(
            "ComfyUIDriver: Download status ${assetResponse.statusCode}",
          );

          if (assetResponse.statusCode == 200) {
            final directory = await path_provider
                .getApplicationSupportDirectory();
            final safeFilename = p.basename(filename);
            final localPath = "${directory.path}/noema/media/$safeFilename";

            final file = File(localPath);
            await file.create(recursive: true);
            await file.writeAsBytes(assetResponse.bodyBytes);
            debugPrint("ComfyUIDriver: Saved to $localPath");

            // --- OUTPUT VERIFICATION ---
            if (!await file.exists()) {
              throw Exception(
                "Output Verification Failed: File does not exist on disk.",
              );
            }
            final length = await file.length();
            if (length == 0) {
              throw Exception("Output Verification Failed: File is 0 bytes.");
            }
            final ext = p.extension(localPath).toLowerCase();
            if (ext != '.png' &&
                ext != '.mp4' &&
                ext != '.webp' &&
                ext != '.gif') {
              throw Exception(
                "Output Verification Failed: Invalid extension '$ext'.",
              );
            }
            // ---------------------------

            return Asset(
              id: filename,
              path: localPath,
              type: isVideo ? AssetType.video : AssetType.image,
            );
          }
        }
      }

      throw Exception(
        "UnsupportedOutput: No image or video files found in the outputs",
      );
    } catch (e) {
      debugPrint("ComfyUIDriver Error in downloadAsset: $e");
      rethrow;
    }
  }

  Future<void> freeVRAM() async {
    try {
      await http.post(
        Uri.parse("$baseUrl/free"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"unload_models": true, "free_memory": true}),
      );
      debugPrint("ComfyUIDriver: Emptied VRAM & freed models via /free");
    } catch (e) {
      debugPrint("ComfyUIDriver: Failed to send /free signal: $e");
    }
  }

  Future<void> cancelJob(String jobId) async {
    try {
      // 1. Remove from pending queue
      await http.post(
        Uri.parse("$baseUrl/queue"),
        body: jsonEncode({
          "delete": [jobId],
        }),
      );

      // 2. Interrupt current running job
      await http.post(Uri.parse("$baseUrl/interrupt"));

      // 3. Emergency VRAM Cleanup
      await freeVRAM();
    } catch (e) {
      debugPrint("ComfyUIDriver Error in cancelJob: $e");
    }
  }
}
