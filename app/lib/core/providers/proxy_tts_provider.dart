import '../plugins/plugin_context.dart';
import 'tts_provider.dart';
import '../../models/job.dart';

class ProxyTTSProvider extends TTSProvider {
  final PluginContext context;

  ProxyTTSProvider(this.context);

  @override
  String get id => "proxy_tts";

  @override
  String get name => "Proxy TTS Provider";

  @override
  bool get available => true;

  @override
  Future<Job> generateAudio(String text, {String? voiceProfile}) {
    final activeId = context.appSettings.activeTtsProvider;
    // Find active provider
    final provider = context.providers.all.whereType<TTSProvider>().firstWhere(
      (p) => p.id == activeId && p.id != "proxy_tts",
      orElse: () => context.providers.all.whereType<TTSProvider>().firstWhere(
            (p) => p.id == 'flutter_tts', // Fallback
          ),
    );

    return provider.generateAudio(text, voiceProfile: voiceProfile);
  }

  @override
  Future<void> cancelJob(String jobId) {
    final activeId = context.appSettings.activeTtsProvider;
    final provider = context.providers.all.whereType<TTSProvider>().firstWhere(
      (p) => p.id == activeId && p.id != "proxy_tts",
      orElse: () => context.providers.all.whereType<TTSProvider>().firstWhere(
            (p) => p.id == 'flutter_tts', // Fallback
          ),
    );
    return provider.cancelJob(jobId);
  }
}
