import '../../core/plugins/plugin_context.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../contracts/execution_request.dart';
import '../contracts/execution_result.dart';

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
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  TTSProvider get _activeProvider {
    final activeId = context.appSettings.activeTtsProvider;
    return context.providers.all.whereType<TTSProvider>().firstWhere(
      (p) => p.id == activeId && p.id != "proxy_tts",
      orElse: () => context.providers.all.whereType<TTSProvider>().firstWhere(
        (p) => p.id == 'flutter_tts', // Fallback
      ),
    );
  }

  @override
  Future<Job> execute(ExecutionRequest request) {
    return _activeProvider.execute(request);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) {
    return _activeProvider.getResult(jobId);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return _activeProvider.cancelJob(jobId);
  }
}
