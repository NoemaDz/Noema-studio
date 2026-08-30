import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'ollama_provider.dart';

class OllamaPlugin extends IPlugin {
  @override
  String get name => 'Ollama LLM';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(OllamaProvider());
  }
}
