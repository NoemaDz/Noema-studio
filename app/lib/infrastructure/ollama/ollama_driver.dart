import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart'; // To access global noema
import '../../core/cancellation_token.dart';

class OllamaDriver {
  String get baseUrl => noema.bootstrap.appSettings.ollamaUrl;

  http.Client? _activeClient;
  bool _isAborting = false;

  Future<String> generateStory(String prompt) async {
    final client = http.Client();
    _activeClient = client;
    _isAborting = false;

    try {
      final response = await client
          .post(
            Uri.parse("$baseUrl/api/generate"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "model": noema.bootstrap.appSettings.llmModelName,
              "stream": false,
              "prompt": prompt,
              "keep_alive": "5m",
              "options": {
                "num_ctx": 8192,
                "num_predict": 4096,
                "temperature": 0.7,
              },
            }),
          )
          .timeout(const Duration(minutes: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["response"];
      } else {
        throw Exception("Failed to generate story");
      }
    } catch (e) {
      if (_isAborting) {
        throw CancelledException();
      }
      rethrow;
    } finally {
      _activeClient = null;
      client.close();
    }
  }

  /// Forcefully closes the active HTTP connection, aborting any in-flight
  /// Ollama generation request. This immediately frees VRAM on the server side.
  void abort() {
    _isAborting = true;
    _activeClient?.close();
    _activeClient = null;
  }
}
