import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';

import 'package:noema_studio/core/plugins/plugin_context.dart';
import 'package:noema_studio/core/settings/app_settings.dart';
import 'package:noema_studio/core/settings/platform_paths.dart';
import 'package:noema_studio/infrastructure/gemini/google_gemini_image_provider.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/pipeline/pipeline_registry.dart';
import 'package:noema_studio/core/workflow/workflow_engine.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/capabilities/capability_resolver.dart';


class MockAppSettings extends AppSettings {
  @override
  String get geminiImageKey => 'test-key';
  @override
  String get geminiImageModel => 'gemini-3.1-flash-image';
  @override
  String get geminiImageAspectRatio => '16:9';
  @override
  String get geminiImageResolution => '1K';
}

class DummyProviderRegistry implements ProviderRegistry {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyPipelineRegistry implements PipelineRegistry {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyWorkflowEngine implements WorkflowEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyJobManager implements JobManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyCapabilityResolver implements CapabilityResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAppSettings mockSettings;
  late PluginContext mockContext;
  late Directory tempDir;

  setUp(() async {
    mockSettings = MockAppSettings();
    mockContext = PluginContext(
      appSettings: mockSettings,
      providers: DummyProviderRegistry(),
      pipelines: DummyPipelineRegistry(),
      engine: DummyWorkflowEngine(),
      jobManager: DummyJobManager(),
      capabilityResolver: DummyCapabilityResolver(),
    );

    // Override platform paths for testing
    tempDir = await Directory.systemTemp.createTemp('gemini_test_');
    PlatformPaths.overrideInstanceForTesting(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    PlatformPaths.resetInstanceForTesting();
  });

  test('Successful image generation and Base64 extraction', () async {
    bool correctPayload = false;
    bool correctHeaders = false;

    final mockClient = MockClient((request) async {
      correctHeaders = request.headers['x-goog-api-key'] == 'test-key';

      final body = jsonDecode(request.body);
      final genConfig = body['generationConfig'];
      correctPayload =
          genConfig != null &&
          genConfig['responseModalities'].contains('IMAGE') &&
          genConfig['imageConfig']['aspectRatio'] == '16:9';

      final dummyBase64 = base64Encode([1, 2, 3, 4, 5]); // Fake image bytes
      final responseBody = jsonEncode({
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "inlineData": {"mimeType": "image/jpeg", "data": dummyBase64},
                },
              ],
            },
          },
        ],
      });
      return http.Response(responseBody, 200);
    });

    final provider = GoogleGeminiImageProvider(mockContext, client: mockClient);
    final request = ExecutionRequest(
      input: "A cute cat",
      capability: CapabilityType.imageGeneration,
    );
    final job = await provider.execute(request);

    // Wait for async generation to finish
    await Future.delayed(const Duration(milliseconds: 100));

    final result = await provider.getResult(job.id);

    expect(
      correctHeaders,
      isTrue,
      reason: 'Headers must include x-goog-api-key',
    );
    expect(
      correctPayload,
      isTrue,
      reason: 'Payload must contain responseModalities and aspectRatio',
    );
    expect(result.isSuccess, isTrue);
    expect(job.status, JobStatus.completed);

    // Verify file exists
    final filePath = result.textOutput;
    expect(filePath, isNotNull);
    final file = File(filePath!);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), [1, 2, 3, 4, 5]);
  });

  test('HTTP/API errors (e.g. 400)', () async {
    final mockClient = MockClient((request) async {
      return http.Response("Bad Request", 400);
    });

    final provider = GoogleGeminiImageProvider(mockContext, client: mockClient);
    final request = ExecutionRequest(
      input: "A cute cat",
      capability: CapabilityType.imageGeneration,
    );
    final job = await provider.execute(request);

    await Future.delayed(const Duration(milliseconds: 100));

    final result = await provider.getResult(job.id);
    expect(!result.isSuccess, isTrue);
    expect(job.status, JobStatus.failed);
    expect(job.metadata["error"], contains("400"));
  });

  test('Malformed Gemini responses', () async {
    final mockClient = MockClient((request) async {
      // Missing candidates
      final responseBody = jsonEncode({"error": "some internal error"});
      return http.Response(responseBody, 200);
    });

    final provider = GoogleGeminiImageProvider(mockContext, client: mockClient);
    final request = ExecutionRequest(
      input: "A cute cat",
      capability: CapabilityType.imageGeneration,
    );
    final job = await provider.execute(request);

    await Future.delayed(const Duration(milliseconds: 100));

    final result = await provider.getResult(job.id);
    expect(!result.isSuccess, isTrue);
    expect(job.status, JobStatus.failed);
    expect(job.metadata["error"], contains("Malformed response"));
  });

  test('HTTP 429 retry behavior', () async {
    int callCount = 0;
    final mockClient = MockClient((request) async {
      callCount++;
      if (callCount <= 2) {
        return http.Response("Rate limited", 429);
      }
      final dummyBase64 = base64Encode([1, 2, 3]);
      final responseBody = jsonEncode({
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "inlineData": {"mimeType": "image/jpeg", "data": dummyBase64},
                },
              ],
            },
          },
        ],
      });
      return http.Response(responseBody, 200);
    });

    final provider = GoogleGeminiImageProvider(mockContext, client: mockClient);
    final request = ExecutionRequest(
      input: "A cute cat",
      capability: CapabilityType.imageGeneration,
    );
    final job = await provider.execute(request);

    // Give it time to retry (will delay 2s then 4s, total 6s, so wait longer)
    // Actually, in a real test we shouldn't wait 6 seconds.
    // Wait, the retry logic uses Future.delayed(Duration(seconds: 2 * retryCount)).
    // I should probably mock the timer or accept the wait. I'll just wait 8 seconds.
    await Future.delayed(const Duration(seconds: 8));

    final result = await provider.getResult(job.id);
    expect(callCount, 3);
    expect(result.isSuccess, isTrue);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('Cancellation', () async {
    final mockClient = MockClient((request) async {
      // Simulate slow response
      await Future.delayed(const Duration(milliseconds: 500));
      return http.Response("{}", 200);
    });

    final provider = GoogleGeminiImageProvider(mockContext, client: mockClient);
    final request = ExecutionRequest(
      input: "A cute cat",
      capability: CapabilityType.imageGeneration,
    );
    final job = await provider.execute(request);

    // Cancel immediately before HTTP request finishes
    await provider.cancelJob(job.id);

    await Future.delayed(const Duration(milliseconds: 600));

    final result = await provider.getResult(job.id);
    expect(!result.isSuccess, isTrue);
    expect(result.error?.code, 'cancelled');
    expect(job.status, JobStatus.cancelled);
  });
}
