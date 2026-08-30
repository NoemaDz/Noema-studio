import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../core/providers/image_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../core/settings/platform_paths.dart';
import '../../core/plugins/plugin_context.dart';
import '../../models/asset_type.dart';
import '../../models/job.dart';
import '../contracts/execution_request.dart';
import '../contracts/execution_result.dart';

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
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final prompt = request.input;
    final apiKey = context.appSettings.openAiKey;
    final url = context.appSettings.openAiUrl;

    if (apiKey.isEmpty) {
      throw Exception("OpenAI API key is missing");
    }

    final jobId = const Uuid().v4();
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
        job.transitionTo(JobStatus.completed);
        job.progress = 1.0;
        job.metadata["url"] = imageUrl;
      } else {
        final job = _jobs[jobId]!;
        job.transitionTo(JobStatus.failed);
        job.metadata["error"] =
            "OpenAI Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      final job = _jobs[jobId]!;
      job.transitionTo(JobStatus.failed);
      job.metadata["error"] = "Exception: $e";
    }
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    final knownJob = _jobs[job.id];
    if (knownJob != null) {
      return JobStatusUpdate(
        status: knownJob.status,
        result: knownJob.result,
        error: knownJob.error,
      );
    }
    return JobStatusUpdate(status: job.status);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) {
      return ExecutionResult.failure(Exception("Job not found"));
    }
    if (job.status != JobStatus.completed) {
      return ExecutionResult.failure(Exception("Job not completed"));
    }

    final imageUrl = job.metadata["url"];
    if (imageUrl == null) {
      return ExecutionResult.failure(Exception("No image URL in metadata"));
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final fileName = "openai_img_$jobId.png";
        final localPath = await PlatformPaths.saveTempFile(
          fileName,
          response.bodyBytes,
        );

        return ExecutionResult.success(textOutput: localPath);
      } else {
        return ExecutionResult.failure(
          Exception("Failed to download image: ${response.statusCode}"),
        );
      }
    } catch (e) {
      return ExecutionResult.failure(Exception("Download failed: $e"));
    }
  }

  @override
  Future<void> cancelJob(String jobId) async {
    // NOTE: This is a logical cancellation.
    // The HTTP request to OpenAI is synchronous and cannot be easily cancelled
    // midway using the standard http package without a dedicated CancelToken/Client.
    // Setting the job to failed ensures the PipelineEngine moves on and ignores the result.
    if (_jobs.containsKey(jobId)) {
      final job = _jobs[jobId]!;
      if (job.status == JobStatus.running ||
          job.status == JobStatus.queued ||
          job.status == JobStatus.starting) {
        job.transitionTo(JobStatus.cancelled);
        job.metadata["error"] = "Cancelled by user";
      }
    }
  }
}
