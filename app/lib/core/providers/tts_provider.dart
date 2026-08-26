import 'provider.dart';
import '../../models/job.dart';

abstract class TTSProvider extends Provider {
  Future<Job> generateAudio(String text, {String? voiceProfile});
  Future<void> cancelJob(String jobId);
}
