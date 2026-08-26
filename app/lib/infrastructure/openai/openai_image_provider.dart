import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../core/providers/image_provider.dart';
import '../../core/settings/platform_paths.dart';
import '../../core/plugins/plugin_context.dart';
import '../../models/asset_type.dart';
import '../../models/job.dart';
import '../../models/asset.dart';

class OpenAIImageProvider extends ImageProvider {
  final PluginContext context;
  final Map<String, Job> _jobs = {};

  OpenAIImageProvider(this.context);

  @override
  String get id => "openai_image";

  @override
  String get name => "OpenAI DALL-E 3";

  @override
  bool get available => context.appSettings.openAiKey.isNotEmpty;

  @override
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) async {
    final apiKey = context.appSettings.openAiKey;
    final url = context.appSettings.openAiUrl;

    if (apiKey.isEmpty) {
      throw Exception("OpenAI API key is missing");
    }

    final jobId = DateTime.now().millisecondsSinceEpoch.toString();
    final job = Job(
      id: jobId,
      providerId: id,
      type: "image",
      status: JobStatus.queued,
      metadata: {"prompt": prompt},
    );
    _jobs[jobId] = job;

    // Start generation asynchronously
    _generateImage(jobId, prompt, apiKey, url);

    return job;
  }

  Future<void> _generateImage(
    String jobId,
    String prompt,
    String apiKey,
    String url,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$url/images/generations"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "dall-e-3",
          "prompt": prompt,
          "n": 1,
          "size": "1024x1024",
          "response_format": "url",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data["data"][0]["url"];

        final job = _jobs[jobId]!;
        job.status = JobStatus.completed;
        job.progress = 1.0;
        job.metadata["url"] = imageUrl;
      } else {
        final job = _jobs[jobId]!;
        job.status = JobStatus.failed;
        job.metadata["error"] =
            "OpenAI Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      final job = _jobs[jobId]!;
      job.status = JobStatus.failed;
      job.metadata["error"] = "Exception: $e";
    }
  }

  @override
  Future<void> updateJobStatus(Job job) async {
    final knownJob = _jobs[job.id];
    if (knownJob != null) {
      job.status = knownJob.status;
      job.result = knownJob.result;
      job.metadata = knownJob.metadata;
    }
  }

  @override
  Future<Asset?> downloadAsset(String jobId) async {
    final job = _jobs[jobId];
    if (job == null || job.status != JobStatus.completed) {
      return null;
    }

    final imageUrl = job.metadata["url"];
    if (imageUrl == null) {
      return null;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final outputDir = PlatformPaths.instance.getJobOutputPath(jobId);
        final file = File(p.join(outputDir, "dalle3_image.png"));
        await file.writeAsBytes(response.bodyBytes);

        return Asset(id: jobId, type: AssetType.image, path: file.path);
      }
    } catch (e) {
      print("Failed to download OpenAI image: $e");
    }
    return null;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    // NOTE: This is a logical cancellation. 
    // The HTTP request to OpenAI is synchronous and cannot be easily cancelled
    // midway using the standard http package without a dedicated CancelToken/Client.
    // Setting the job to failed ensures the PipelineEngine moves on and ignores the result.
    if (_jobs.containsKey(jobId)) {
      final job = _jobs[jobId]!;
      if (job.status == JobStatus.running) {
        job.status = JobStatus.failed;
        job.metadata["error"] = "Cancelled by user";
      }
    }
  }
}
