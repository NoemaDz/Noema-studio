import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:uuid/uuid.dart';

import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class MockTTSProvider extends TTSProvider {
  @override
  String get id => "mock_tts";

  @override
  String get name => "Mock TTS";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  final Map<String, ExecutionResult> _results = {};

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final jobId = request.jobId ?? "tts_mock_${const Uuid().v4()}";
    final text = request.input;
    final voiceProfile = request.parameters['voiceProfile'] as String?;

    final job = Job(
      id: jobId,
      providerId: id,
      type: request.capability.name,
      metadata: {"text": text, "voiceProfile": voiceProfile},
      status: JobStatus.running,
    );

    _runAsync(job);
    return job;
  }

  Future<void> _runAsync(Job job) async {
    await Future.delayed(const Duration(seconds: 1));
    _results[job.id] = ExecutionResult.success(
      textOutput: "path/to/mock_audio.mp3",
    );
    job.transitionTo(JobStatus.completed);
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
