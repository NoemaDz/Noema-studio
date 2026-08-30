import '../../core/plugins/plugin_context.dart';
import 'llm_provider.dart';
import '../plugins/plugin_context.dart';
import '../../models/job.dart';
import '../contracts/execution_request.dart';
import '../contracts/execution_result.dart';
import '../../core/capabilities/capability.dart';

class ProxyLLMProvider extends LLMProvider {
  final PluginContext context;

  ProxyLLMProvider(this.context);

  @override
  String get id => "proxy_llm";

  @override
  String get name => "Proxy LLM Provider";

  @override
  bool get available => _activeProvider.available;

  @override
  Set<CapabilityType> get capabilities => _activeProvider.capabilities;

  @override
  HardwareRequirements get hardwareRequirements =>
      _activeProvider.hardwareRequirements;

  LLMProvider get _activeProvider {
    final activeId = context.appSettings.activeLlmProvider;
    final provider = context.providers.all.whereType<LLMProvider>().firstWhere(
      (p) => p.id == activeId,
      orElse: () => context.providers.getDefault<LLMProvider>(),
    );
    return provider;
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
