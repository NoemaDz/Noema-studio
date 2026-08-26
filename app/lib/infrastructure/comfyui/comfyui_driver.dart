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
import 'comfyui_workflow_adapter.dart';

class ComfyUIDriver {
  final PluginContext context;

  ComfyUIDriver(this.context);

  String get baseUrl => context.appSettings.comfyUIUrl;

  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) async {
    final bool isVideo = options?["is_video"] == true;
    final String? sourceImagePath = options?["source_image_path"];

    // Check if we have characters for IP-Adapter (only for images)
    final List<dynamic>? characters = options?["characters"];
    final bool useIpAdapter =
        !isVideo && characters != null && characters.isNotEmpty;

    // Upload character images first (for IP-Adapter)
    List<dynamic> uploadedCharacters = [];
    if (useIpAdapter) {
      if (characters.length > 3) {
        throw Exception(
            "Maximum 3 characters supported for regional identity per scene. Found ${characters.length}.");
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

    final retryPolicy = const RetryPolicy(maxRetries: 3);

    final response = await retryPolicy.execute(
      () => http
          .post(
            Uri.parse("$baseUrl/prompt"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"prompt": adapter.toJson()}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (response.statusCode != 200) {
      throw Exception(
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

  Future<void> updateJobStatus(Job job) async {
    try {
      final queueResponse = await http
          .get(Uri.parse("$baseUrl/queue"))
          .timeout(const Duration(seconds: 5));
      if (queueResponse.statusCode == 200) {
        final queueData = jsonDecode(queueResponse.body);
        final running = queueData["queue_running"] as List;
        final pending = queueData["queue_pending"] as List;

        if (running.any((q) => q[1] == job.id)) {
          job.status = JobStatus.running;
          return;
        }
        if (pending.any((q) => q[1] == job.id)) {
          job.status = JobStatus.queued;
          return;
        }
      }

      final historyResponse = await http
          .get(Uri.parse("$baseUrl/history/${job.id}"))
          .timeout(const Duration(seconds: 5));
      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        if (historyData.containsKey(job.id)) {
          final jobHistory = historyData[job.id];
          // Check if there is an error in the status object
          if (jobHistory['status'] != null &&
              jobHistory['status']['status_str'] == 'error') {
            job.status = JobStatus.failed;
            
            // Attempt to parse the error message securely
            try {
              final messages = jobHistory['status']['messages'] as List;
              if (messages.isNotEmpty) {
                // Usually errors are in messages[0][1][0] or similar, let's grab the exception message
                final firstMsg = messages.first;
                final exceptionNode = firstMsg[1]?[0] ?? firstMsg.toString();
                // We'll provide a clear error message depending on what is returned
                job.result = exceptionNode.toString();
              } else {
                job.result = "Unknown ComfyUI Error";
              }
            } catch (e) {
              job.result = "Failed to parse ComfyUI error: $e";
            }
            return;
          }
          job.status = JobStatus.completed;
          return;
        }
      }
    } catch (e) {
      debugPrint("ComfyUIDriver Error in updateJobStatus: $e");
      // Throw exception to allow callers (like JobManager) to retry via RetryPolicy
      // instead of marking the job as permanently failed due to a transient network error.
      throw Exception("Network error while getting job status: $e");
    }

    // If we reach here without exception and it's not found in queue or history, it might be an unknown state.
    // However, keeping fallback to failed for now, but transient errors will be caught above.
    job.status = JobStatus.failed;
    job.result = "Job not found in queue or history";
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

      if (data.isEmpty) {
        debugPrint("ComfyUIDriver: downloadAsset history data empty");
        return null;
      }

      final outputs = data[jobId]["outputs"] as Map<String, dynamic>;

      debugPrint("ComfyUIDriver: Checking outputs... ${outputs.keys}");
      for (final node in outputs.values) {
        debugPrint("ComfyUIDriver: Node keys: ${(node as Map).keys}");
        if (node["images"] != null || node["gifs"] != null) {
          final isVideo = node["gifs"] != null;
          final filename = isVideo
              ? node["gifs"][0]["filename"]
              : node["images"][0]["filename"];

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

            return Asset(
              id: filename,
              path: localPath,
              type: isVideo ? AssetType.video : AssetType.image,
            );
          }
        }
      }
      debugPrint("ComfyUIDriver: Finished loop without returning asset.");
    } catch (e) {
      debugPrint("ComfyUIDriver Error in downloadAsset: $e");
    }

    return null;
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
    } catch (e) {
      debugPrint("ComfyUIDriver Error in cancelJob: $e");
    }
  }
}
