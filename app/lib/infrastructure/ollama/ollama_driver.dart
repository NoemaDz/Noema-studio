import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart'; // To access global noema

class OllamaDriver {
  String get baseUrl => noema.bootstrap.appSettings.ollamaUrl;

  Future<String> generateStory(String prompt) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/generate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "model": noema.bootstrap.appSettings.llmModelName,
        "format": "json",
        "stream": false,
        "prompt": prompt,
        "options": {"num_predict": 4096, "temperature": 0.7},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["response"];
    } else {
      throw Exception("Failed to generate story");
    }
  }
}
