import '../../core/providers/llm_provider.dart';
import 'ollama_driver.dart';

class OllamaProvider extends LLMProvider {
  final OllamaDriver service = OllamaDriver();

  @override
  String get id => "ollama";

  @override
  String get name => "Ollama";

  @override
  bool get available => true;

  @override
  Future<String> generate(String prompt) {
    return service.generateStory(prompt);
  }
}