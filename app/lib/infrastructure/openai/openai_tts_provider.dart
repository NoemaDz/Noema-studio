import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../main.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class OpenAITTSProvider extends TTSProvider {
  @override
  String get id => "openai_tts";

  @override
  String get name => "OpenAI TTS API";

  @override
  bool get available => noema.bootstrap.appSettings.openAiKey.isNotEmpty;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  final Map<String, ExecutionResult> _results = {};

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final jobId = request.jobId ?? "tts_${const Uuid().v4()}";
    final text = request.input;
    final voiceProfile = request.parameters['voiceProfile'] as String?;

    final appDir = await getApplicationSupportDirectory();
    final outputDir = Directory(
      p.join(appDir.path, "noema", "output", "audio"),
    );
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final fileName = "$jobId.mp3";
    final outputPath = p.join(outputDir.path, fileName);

    final apiKey = noema.bootstrap.appSettings.openAiKey;
    final voice = voiceProfile ?? noema.bootstrap.appSettings.openAiTtsVoice;

    final job = Job(
      id: jobId,
      providerId: id,
      type: request.capability.name,
      status: JobStatus.running,
    );

    if (apiKey.isEmpty) {
      job.transitionTo(JobStatus.failed);
      job.error = JobError(
        code: 'auth_error',
        message: 'OpenAI API key is missing.',
      );
      _results[jobId] = ExecutionResult.failure(job.error!);
      return job;
    }

    _runAsync(job, text, voice, outputPath, apiKey);
    return job;
  }

  Future<void> _runAsync(
    Job job,
    String text,
    String voice,
    String outputPath,
    String apiKey,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/audio/speech'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1', // or tts-1-hd
          'input': text,
          'voice': voice.toLowerCase(),
        }),
      );

      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);

        _results[job.id] = ExecutionResult.success(textOutput: outputPath);
        job.transitionTo(JobStatus.completed);
      } else {
        _results[job.id] = ExecutionResult.failure(
          JobError(
            code: 'http_error',
            message:
                'Failed with status ${response.statusCode}: ${response.body}',
          ),
        );
        job.error = JobError(
          code: 'http_error',
          message:
              'Failed with status ${response.statusCode}: ${response.body}',
        );
        job.transitionTo(JobStatus.failed);
      }
    } catch (e) {
      _results[job.id] = ExecutionResult.failure(
        JobError(code: 'error', message: e.toString()),
      );
      job.error = JobError(code: 'error', message: e.toString());
      job.transitionTo(JobStatus.failed);
    }
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    return _results[jobId] ??
        ExecutionResult.failure(
          JobError(code: 'not_found', message: 'Result not found'),
        );
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
