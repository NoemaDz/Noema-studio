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
  Future<Job> generateAudio(String text) async {
    return Job(
      id: "mock_audio_${DateTime.now().millisecondsSinceEpoch}",
      providerId: id,
      type: "audio",
      metadata: {"text": text},
      status: JobStatus.completed,
      progress: 1.0,
      result: "path/to/mock_audio.mp3",
    );
  }
}
