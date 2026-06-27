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
  "format": "json",
  "stream": false,
  "prompt": """
Return ONLY valid JSON.

Schema:

{
  "title": "string",
  "scenes": [
    {
      "id": 1,
      "description": "string"
    }
  ]
}

Generate 5 scenes.

User idea:
$prompt
"""

        
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