import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import '../../core/providers/llm_provider.dart';
import 'openai_driver.dart';

class OpenAIProvider extends LLMProvider {
  final OpenAIDriver _driver = OpenAIDriver();

  @override
  String get id => 'openai';

  @override
  String get name => 'Generic OpenAI Compatible API';

  @override
  bool get available => true; // Always available, errors out if no connection

  @override
  Future<String> generate(String prompt) async {
    return _driver.generateStory(prompt);
  }
}

class OpenAIPlugin extends IPlugin {
  @override
  String get name => 'OpenAI API Plugin';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(OpenAIProvider());
  }
}
