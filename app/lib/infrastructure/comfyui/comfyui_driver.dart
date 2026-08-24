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

class ComfyUIDriver {
  final PluginContext context;
  
  ComfyUIDriver(this.context);

  String get baseUrl => context.appSettings.comfyUIUrl;

  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) async {
    // Check if we have characters for IP-Adapter
    final List<dynamic>? characters = options?["characters"];
    final bool useIpAdapter = characters != null && characters.isNotEmpty;

    String workflowPath = useIpAdapter
        ? "assets/workflows/ip_adapter_api.json"
        : "assets/workflows/text_to_image_api.json";

    String workflow;
    try {
      workflow = await rootBundle.loadString(workflowPath);
    } catch (e) {
      debugPrint(
        "ComfyUIDriver: Failed to load $workflowPath ($e), falling back to text_to_image_api.json",
      );
      workflowPath = "assets/workflows/text_to_image_api.json";
      workflow = await rootBundle.loadString(workflowPath);
    }

    final Map<String, dynamic> json = jsonDecode(workflow);

    // Default Prompt Injection
    if (json.containsKey("3")) {
      json["3"]["inputs"]["text"] = prompt;
    }

    // IP-Adapter Character Injection Logic
    // This expects the ip_adapter_api.json to have specific nodes set up.
    // Example:
    // Node 100+: LoadImage (for character references)
    // Node 200+: IPAdapterApply (for applying the reference to the model)
    // Node 300+: SolidMask (for regional prompting)
    if (useIpAdapter) {
      for (int i = 0; i < characters.length; i++) {
        final charData = characters[i] as Map<String, dynamic>;
        // We assume the user has set up the JSON with LoadImage nodes starting at ID 100
        final imageNodeId = (100 + i).toString();

        if (json.containsKey(imageNodeId) &&
            json[imageNodeId]["class_type"] == "LoadImage") {
          // Strip out the baseUrl/view?filename= part and keep just the filename
          final String fullPath = charData["imagePath"];
          final Uri uri = Uri.parse(fullPath);
          final String filename =
              uri.queryParameters["filename"] ?? "image.png";

          json[imageNodeId]["inputs"]["image"] = filename;
        }
      }
    }

    final response = await http.post(
      Uri.parse("$baseUrl/prompt"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"prompt": json}),
    );

    final data = jsonDecode(response.body);

    return Job(id: data["prompt_id"], type: "image", status: JobStatus.queued);
  }

  Future<JobStatus> getJobStatus(String jobId) async {
    try {
      final queueResponse = await http.get(Uri.parse("$baseUrl/queue"));
      if (queueResponse.statusCode == 200) {
        final queueData = jsonDecode(queueResponse.body);
        final running = queueData["queue_running"] as List;
        final pending = queueData["queue_pending"] as List;
        
        if (running.any((q) => q[1] == jobId)) return JobStatus.running;
        if (pending.any((q) => q[1] == jobId)) return JobStatus.queued;
      }
      
      final historyResponse = await http.get(Uri.parse("$baseUrl/history/$jobId"));
      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        if (historyData.containsKey(jobId)) {
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
      final response = await http.get(Uri.parse("$baseUrl/history/$jobId"));

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
          final assetResponse = await http.get(Uri.parse(assetUrl));
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
