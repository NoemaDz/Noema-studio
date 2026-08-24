import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart';

class OpenAIDriver {
  String get baseUrl => noema.bootstrap.appSettings.openAiUrl;
  String get apiKey => noema.bootstrap.appSettings.openAiKey;
  String get modelName => noema.bootstrap.appSettings.openAiModel;

  Future<String> generateStory(String prompt) async {
    final response = await http.post(
      Uri.parse("$baseUrl/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        if (apiKey.isNotEmpty) "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": modelName,
        "messages": [
          {
            "role": "system",
            "content":
                "You are a creative story generator. Return ONLY valid JSON.",
          },
          {"role": "user", "content": prompt},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } else {
      throw Exception(
        "Failed to generate story with OpenAI/Generic API: ${response.statusCode} - ${response.body}",
      );
    }
  }
}
