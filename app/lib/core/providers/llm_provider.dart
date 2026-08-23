import 'provider.dart';

abstract class LLMProvider extends Provider {
  Future<String> generate(String prompt);
}