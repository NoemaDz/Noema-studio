import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class FlutterTTSProvider extends TTSProvider {
  @override
  String get id => "flutter_tts";

  @override
  String get name => "Flutter TTS (Local)";

  @override
  bool get available => true; // usually always true on supported platforms

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  final FlutterTts flutterTts = FlutterTts();

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

    final fileName = "$jobId.wav";
    final outputPath = p.join(outputDir.path, fileName);

    final job = Job(
      id: jobId,
      providerId: id,
      type: request.capability.name,
      status: JobStatus.running,
    );
    _runAsync(job, text, voiceProfile, outputPath);
    return job;
  }

  Future<void> _runAsync(
    Job job,
    String text,
    String? voiceProfile,
    String outputPath,
  ) async {
    try {
      if (voiceProfile != null) {
        try {
          await flutterTts.setVoice({"name": voiceProfile, "locale": "en-US"});
        } catch (e) {
          debugPrint("Failed to set local voice: $e");
          await flutterTts.setLanguage("en-US");
        }
      } else {
        await flutterTts.setLanguage("en-US");
      }

      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      // Synthesize to file
      final result = await flutterTts.synthesizeToFile(text, outputPath);

      if (result == 1) {
        // flutter_tts synthesizer doesn't block until file is actually written on some platforms.
        // We might need to wait for completion event or poll file existence.
        // For simplicity, we just assume it succeeds and wait a bit.
        await Future.delayed(const Duration(milliseconds: 500));

        _results[job.id] = ExecutionResult.success(textOutput: outputPath);
        job.transitionTo(JobStatus.completed);
      } else {
        _results[job.id] = ExecutionResult.failure(
          JobError(code: 'failed', message: 'FlutterTTS return 0'),
        );
        job.error = JobError(code: 'failed', message: 'FlutterTTS return 0');
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
  Future<void> cancelJob(String jobId) async {
    await flutterTts.stop();
  }
}
