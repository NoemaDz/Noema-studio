import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:uuid/uuid.dart';

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

  @override
  Future<Job> generateAudio(String text, {String? voiceProfile}) async {
    final jobId = "tts_mock_${const Uuid().v4()}";

    // Simulate some network delay
    await Future.delayed(const Duration(seconds: 1));
    return Job(
      id: jobId,
      providerId: id,
      type: "audio",
      metadata: {"text": text, "voiceProfile": voiceProfile},
      status: JobStatus.completed,
      progress: 1.0,
      result: "path/to/mock_audio.mp3",
    );
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
