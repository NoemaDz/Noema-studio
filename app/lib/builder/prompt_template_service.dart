import 'package:flutter/services.dart';

class PromptTemplateService {
  Future<String> load(String template, Map<String, String> variables) async {
    String content = await rootBundle.loadString("assets/prompts/$template.md");

    variables.forEach((key, value) {
      content = content.replaceAll("{{$key}}", value);
    });

    return content;
  }
}
