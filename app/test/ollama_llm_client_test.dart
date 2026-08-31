import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:noema_studio/infrastructure/ollama/ollama_llm_client.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return handler(request);
  }
}

void main() {
  group('OllamaLlmClient', () {
    const baseUrl = 'http://localhost:11434';
    const modelName = 'llama3';

    test('successfully parses valid JSON response', () async {
      final mockClient = MockHttpClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/generate');
        expect(request.headers['Content-Type'], 'application/json');

        return http.StreamedResponse(
          Stream.value(
            utf8.encode(jsonEncode({'response': 'some text response'})),
          ),
          200,
        );
      });

      final client = OllamaLlmClient(
        baseUrl: baseUrl,
        modelName: modelName,
        client: mockClient,
      );

      final result = await client.generateText('hello');
      expect(result, 'some text response');
    });

    test('throws LlmConnectionException on SocketException', () async {
      final mockClient = MockHttpClient((request) async {
        throw const SocketException('Connection refused');
      });

      final client = OllamaLlmClient(
        baseUrl: baseUrl,
        modelName: modelName,
        client: mockClient,
      );

      await expectLater(
        client.generateText('hello'),
        throwsA(isA<LlmConnectionException>()),
      );
    });

    test('throws LlmTimeoutException on TimeoutException', () async {
      final mockClient = MockHttpClient((request) async {
        // Simulate hanging request
        await Future.delayed(const Duration(seconds: 1));
        return http.StreamedResponse(Stream.empty(), 200);
      });

      final client = OllamaLlmClient(
        baseUrl: baseUrl,
        modelName: modelName,
        timeout: const Duration(milliseconds: 100),
        client: mockClient,
      );

      await expectLater(
        client.generateText('hello'),
        throwsA(isA<LlmTimeoutException>()),
      );
    });

    test('throws FormatException on malformed JSON response', () async {
      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('invalid json {')),
          200,
        );
      });

      final client = OllamaLlmClient(
        baseUrl: baseUrl,
        modelName: modelName,
        client: mockClient,
      );

      await expectLater(
        client.generateText('hello'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws Exception on non-200 status code', () async {
      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('Internal Server Error')),
          500,
        );
      });

      final client = OllamaLlmClient(
        baseUrl: baseUrl,
        modelName: modelName,
        client: mockClient,
      );

      await expectLater(
        client.generateText('hello'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString',
            contains('API returned status code 500'),
          ),
        ),
      );
    });
  });
}
