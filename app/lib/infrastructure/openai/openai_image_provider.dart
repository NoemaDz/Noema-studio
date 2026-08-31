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

class OpenAIImageProvider extends ImageProvider {
  final PluginContext context;
  final Map<String, ExecutionResult> _results = {};
  final List<String> _cancelledJobs = [];

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

    if (_cancelledJobs.contains(jobId)) {
      job.transitionTo(JobStatus.cancelled);
      job.result = "Job cancelled by user";
      _results[jobId] = ExecutionResult.failure(
        JobError(code: 'cancelled', message: 'Job cancelled by user'),
      );
      _cancelledJobs.remove(jobId);
      return job;
    }

    // Start generation asynchronously
    _generateImage(job, prompt, apiKey, url);

    return job;
  }

  Future<void> _generateImage(
    Job job,
    String prompt,
    String apiKey,
    String url,
  ) async {
    final jobId = job.id;
    try {
      if (_cancelledJobs.contains(jobId)) {
        throw Exception("Cancelled by user");
      }

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

      if (_cancelledJobs.contains(jobId)) {
        throw Exception("Cancelled by user");
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data["data"][0]["url"];

        final imgResponse = await http.get(Uri.parse(imageUrl));
        if (imgResponse.statusCode == 200) {
          final outputDir = PlatformPaths.instance.getJobOutputPath(jobId);
          final file = File(p.join(outputDir, "openai_img_$jobId.png"));
          await file.writeAsBytes(imgResponse.bodyBytes);

          _results[jobId] = ExecutionResult.success(textOutput: file.path);
          job.transitionTo(JobStatus.completed);
          job.progress = 1.0;
          job.metadata["url"] = imageUrl;
          job.result = file.path;
        } else {
          _results[jobId] = ExecutionResult.failure(
            JobError(
              code: 'download_failed',
              message: 'Failed to download image',
            ),
          );
          job.transitionTo(JobStatus.failed);
          job.metadata["error"] = "Download failed: ${imgResponse.statusCode}";
        }
      } else {
        _results[jobId] = ExecutionResult.failure(
          JobError(
            code: 'api_error',
            message: 'OpenAI Error: ${response.statusCode}',
          ),
        );
        job.transitionTo(JobStatus.failed);
        job.metadata["error"] =
            "OpenAI Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      if (_cancelledJobs.contains(jobId)) {
        _results[jobId] = ExecutionResult.failure(
          JobError(code: 'cancelled', message: 'Job cancelled by user'),
        );
        job.transitionTo(JobStatus.cancelled);
        job.metadata["error"] = "Cancelled by user";
      } else {
        _results[jobId] = ExecutionResult.failure(
          JobError(code: 'exception', message: e.toString()),
        );
        job.transitionTo(JobStatus.failed);
        job.metadata["error"] = "Exception: $e";
      }
    } finally {
      _cancelledJobs.remove(jobId);
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
