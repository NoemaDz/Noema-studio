import '../../core/plugins/plugin_context.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/capabilities/capability.dart';

class ProxyLLMProvider extends LLMProvider {
  final PluginContext context;

  ProxyLLMProvider(this.context);

  @override
  String get id => "proxy_llm";

  @override
  String get name => "Proxy LLM Provider";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  @override
  Future<String> generate(String prompt) {
    final activeId = context.appSettings.activeLlmProvider;
    // Find the provider with this id
    final provider = context.providers.all.whereType<LLMProvider>().firstWhere(
      (p) => p.id == activeId,
      orElse: () => context.providers.getDefault<LLMProvider>(),
    );
    return provider.generate(prompt);
  }
}
