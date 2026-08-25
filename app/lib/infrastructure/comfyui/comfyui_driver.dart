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
    // Check if we have characters for IP-Adapter
    final List<dynamic>? characters = options?["characters"];
    final bool useIpAdapter = characters != null && characters.isNotEmpty;

    // Upload character images first
    List<dynamic> uploadedCharacters = [];
    if (useIpAdapter) {
      for (final char in characters) {
        final path = char["imagePath"] as String;
        try {
          final uploadedName = await _uploadImage(path);
          uploadedCharacters.add({"imagePath": uploadedName});
        } catch (e) {
          debugPrint(
            "Warning: Failed to upload character image $path. Error: $e",
          );
          uploadedCharacters.add(char); // Fallback to original
        }
      }
    }

    String workflowPath = useIpAdapter
        ? "assets/workflows/ip_adapter_api.json"
        : "assets/workflows/text_to_image_api.json";

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

    // Apply resolution from settings
    final resolution = context.appSettings.imageResolution;
    adapter.setResolution(resolution);

    // Semantic Injection
    adapter.setPrompt(prompt);

    if (useIpAdapter) {
      adapter.setCharacterImages(uploadedCharacters);
    }

    // Apply or disable Detailer based on settings
    final useDetailer = context.appSettings.useDetailer;
    if (!useDetailer && useIpAdapter) {
      adapter.disableDetailer();
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
      providerId: "comfyui",
      type: "image",
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

  Future<JobStatus> getJobStatus(String jobId) async {
    try {
      final queueResponse = await http
          .get(Uri.parse("$baseUrl/queue"))
          .timeout(const Duration(seconds: 5));
      if (queueResponse.statusCode == 200) {
        final queueData = jsonDecode(queueResponse.body);
        final running = queueData["queue_running"] as List;
        final pending = queueData["queue_pending"] as List;

        if (running.any((q) => q[1] == jobId)) return JobStatus.running;
        if (pending.any((q) => q[1] == jobId)) return JobStatus.queued;
      }

      final historyResponse = await http
          .get(Uri.parse("$baseUrl/history/$jobId"))
          .timeout(const Duration(seconds: 5));
      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        if (historyData.containsKey(jobId)) {
          final jobHistory = historyData[jobId];
          // Check if there is an error in the status object
          if (jobHistory['status'] != null &&
              jobHistory['status']['status_str'] == 'error') {
            return JobStatus.failed;
          }
          return JobStatus.completed;
        }
      }
    } catch (e) {
      debugPrint("ComfyUIDriver Error in getJobStatus: $e");
    }

    return JobStatus.failed;
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
      await http.post(Uri.parse("$baseUrl/interrupt"));
    } catch (e) {
      debugPrint("ComfyUIDriver Error in cancelJob: $e");
    }
  }
}
