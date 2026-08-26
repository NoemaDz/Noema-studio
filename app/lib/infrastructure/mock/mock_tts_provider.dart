import '../../core/providers/tts_provider.dart';
import '../../models/job.dart';

class MockTTSProvider extends TTSProvider {
  @override
  String get id => "mock_tts";

  @override
  String get name => "Mock TTS";

  @override
  bool get available => true;

  @override
  Future<Job> generateAudio(String text, {String? voiceProfile}) async {
    final jobId = "tts_mock_${DateTime.now().millisecondsSinceEpoch}";
    
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
