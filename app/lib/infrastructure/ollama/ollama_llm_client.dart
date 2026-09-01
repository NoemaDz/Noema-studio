import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../agent/llm_client.dart';

class LlmConnectionException implements Exception {
  final String message;
  LlmConnectionException(this.message);
  @override
  String toString() => 'LlmConnectionException: $message';
}

class LlmTimeoutException implements Exception {
  final String message;
  LlmTimeoutException(this.message);
  @override
  String toString() => 'LlmTimeoutException: $message';
}

class LlmHttpException implements Exception {
  final int statusCode;
  final String message;
  LlmHttpException(this.statusCode, this.message);
  @override
  String toString() => 'LlmHttpException: $statusCode $message';
}

class OllamaLlmClient implements LlmClient {
  final String baseUrl;
  final String modelName;
  final Duration timeout;
  final http.Client _client;

  OllamaLlmClient({
    required this.baseUrl,
    required this.modelName,
    this.timeout = const Duration(minutes: 2),
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<String> generateText(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': modelName,
              'prompt': prompt,
              'format': 'json',
              'stream': false,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['response'];
        if (responseText == null || responseText is! String) {
          throw const FormatException(
            'Ollama response did not contain a valid "response" string field',
          );
        }
        return responseText;
      } else {
        throw LlmHttpException(response.statusCode, response.body);
      }
    } on TimeoutException {
      throw LlmTimeoutException(
        'Ollama API request timed out after ${timeout.inSeconds} seconds',
      );
    } on SocketException catch (e) {
      throw LlmConnectionException(
        'Failed to connect to Ollama at $baseUrl: $e',
      );
    } catch (e) {
      if (e is FormatException ||
          e is LlmConnectionException ||
          e is LlmTimeoutException ||
          e is LlmHttpException) {
        rethrow;
      }
      throw Exception('Unexpected error communicating with Ollama: $e');
    }
  }
}
