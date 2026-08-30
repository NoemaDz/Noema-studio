import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../main.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class EdgeTTSProvider extends TTSProvider {
  @override
  String get id => "edge_tts";

  @override
  String get name => "Microsoft Edge TTS (Free)";

  @override
  bool get available => true; // Edge TTS requires no API key

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

    final voice = voiceProfile ?? noema.bootstrap.appSettings.edgeTtsVoice;

    final job = Job(
      id: jobId,
      providerId: id,
      type: request.capability.name,
      status: JobStatus.running,
    );

    _runAsync(job, text, voice, outputPath);
    return job;
  }

  Future<void> _runAsync(
    Job job,
    String text,
    String voice,
    String outputPath,
  ) async {
    try {
      ProcessResult? result;
      final home = Platform.environment['HOME'] ?? '';
      final possiblePaths = [
        'edge-tts', // In PATH
        p.join(home, '.local', 'bin', 'edge-tts'), // pipx or pip --user
        p.join(home, 'myenv', 'bin', 'edge-tts'), // The user's myenv
        'python3', // fallback to python module
      ];

      final List<String> errors = [];

      for (final binPath in possiblePaths) {
        try {
          if (binPath == 'python3') {
            print("Trying python3 -m edge_tts...");
            result = await Process.run('python3', [
              '-m',
              'edge_tts',
              '--voice',
              voice,
              '--text',
              text,
              '--write-media',
              outputPath,
            ]);
          } else {
            result = await Process.run(binPath, [
              '--voice',
              voice,
              '--text',
              text,
              '--write-media',
              outputPath,
            ]);
          }

          if (result.exitCode == 0) {
            break; // Success!
          } else {
            errors.add("$binPath failed: ${result.stderr}");
          }
        } catch (e) {
          errors.add("$binPath execution error: $e");
        }
      }

      if (result != null &&
          result.exitCode == 0 &&
          File(outputPath).existsSync()) {
        _results[job.id] = ExecutionResult.success(textOutput: outputPath);
        job.transitionTo(JobStatus.completed);
      } else {
        final errorMessage =
            "Edge TTS failed after trying multiple paths:\n" +
            errors.join('\n');
        _results[job.id] = ExecutionResult.failure(
          JobError(code: 'exec_error', message: errorMessage),
        );
        job.error = JobError(code: 'exec_error', message: errorMessage);
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
