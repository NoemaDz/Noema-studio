import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  static const String baseUrl = "http://localhost:11434";

  Future<String> generateStory(String prompt) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/generate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "model": "qwen3:8b",
        "prompt": """
You are a professional cartoon script writer.

Write a complete cartoon story based on the user's idea.

Rules:
- Be creative.
- Write in English.
- Include a title.
- Divide the story into scenes.
- Each scene should be visually descriptive.
- Do not ask questions.
- Start writing immediately.

User idea:
$prompt
""",
        "stream": false,
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