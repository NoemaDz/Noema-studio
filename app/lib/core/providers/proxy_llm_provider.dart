import '../plugins/plugin_context.dart';
import 'llm_provider.dart';
import '../../main.dart'; // to access noema global

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
  Future<String> generate(String prompt) {
    final activeId = noema.bootstrap.appSettings.activeLlmProvider;
    // Find the provider with this id
    final provider = context.providers.all.whereType<LLMProvider>().firstWhere(
      (p) => p.id == activeId,
      orElse: () => context.providers.getDefault<LLMProvider>(),
    );
    return provider.generate(prompt);
  }
}
