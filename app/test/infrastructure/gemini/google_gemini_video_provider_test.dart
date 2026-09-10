import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/plugins/plugin_context.dart';
import 'package:noema_studio/core/settings/app_settings.dart';
import 'package:noema_studio/core/settings/platform_paths.dart';
import 'package:noema_studio/infrastructure/gemini/google_gemini_video_provider.dart';
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
  String get geminiVideoKey => 'test-key';
  @override
  String get geminiVideoModel => 'veo-3.1-generate-preview';
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

class MockJobManager implements JobManager {
  final Map<String, Job> _jobs = {};

  @override
  Job? find(String id) => _jobs[id];

  @override
  Job add(Job job) {
    _jobs[job.id] = job;
    return job;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyCapabilityResolver implements CapabilityResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAppSettings mockSettings;
  late MockJobManager mockJobManager;
  late PluginContext mockContext;
  late Directory tempDir;
  late File dummyImageFile;

  setUp(() async {
    mockSettings = MockAppSettings();
    mockJobManager = MockJobManager();
    mockContext = PluginContext(
      appSettings: mockSettings,
      providers: DummyProviderRegistry(),
      pipelines: DummyPipelineRegistry(),
      engine: DummyWorkflowEngine(),
      jobManager: mockJobManager,
      capabilityResolver: DummyCapabilityResolver(),
    );

    // Override platform paths for testing
    tempDir = await Directory.systemTemp.createTemp('gemini_video_test_');
    PlatformPaths.overrideInstanceForTesting(tempDir.path);

    dummyImageFile = File('${tempDir.path}/test_image.jpg');
    await dummyImageFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    PlatformPaths.resetInstanceForTesting();
  });

  test('Successful predictLongRunning request and operation polling', () async {
    bool correctExecutionPayload = false;
    bool correctExecutionHeaders = false;
    bool correctPollingHeaders = false;
    bool correctDownloadHeaders = false;
    bool downloadAttempted = false;

    final operationName = 'operations/test-123';
    final videoUri = 'https://example.com/video.mp4';
    final videoBytes = [10, 20, 30];

    final mockClient = MockClient((request) async {
      if (request.method == 'POST') {
        correctExecutionHeaders =
            request.headers['x-goog-api-key'] == 'test-key';
        final body = jsonDecode(request.body);

        correctExecutionPayload =
            body['instances'] != null &&
            body['instances'][0]['image'] != null &&
            body['instances'][0]['image']['bytesBase64Encoded'] != null &&
            body['instances'][0]['image']['mimeType'] != null;

        return http.Response(jsonEncode({"name": operationName}), 200);
      } else if (request.method == 'GET' &&
          request.url.toString().contains(operationName)) {
        correctPollingHeaders = request.headers['x-goog-api-key'] == 'test-key';

        final response = {
          "name": operationName,
          "done": true,
          "response": {
            "generateVideoResponse": {
              "generatedSamples": [
                {
                  "video": {"uri": videoUri},
                },
              ],
            },
          },
        };
        return http.Response(jsonEncode(response), 200);
      } else if (request.method == 'GET' &&
          request.url.toString() == videoUri) {
        correctDownloadHeaders =
            request.headers['x-goog-api-key'] == 'test-key';
        downloadAttempted = true;
        return http.Response.bytes(
          videoBytes,
          200,
          request: request,
          headers: {'content-type': 'video/mp4'},
        );
      }

      return http.Response('Not Found', 404);
    });

    final provider = GoogleGeminiVideoProvider(mockContext, client: mockClient);

    // 1. Execute
    final request = ExecutionRequest(
      capability: CapabilityType.videoGeneration,
      input: 'A flying bird',
      parameters: {'imagePath': dummyImageFile.path},
    );

    final job = await provider.execute(request);

    expect(job.status, JobStatus.queued);
    expect(job.providerId, 'gemini_video');

    expect(correctExecutionHeaders, true);
    expect(correctExecutionPayload, true);
    expect(job.metadata["operation_name"], operationName);

    mockJobManager.add(job);

    // 2. Poll Status (which completes and downloads)
    final update = await provider.updateJobStatus(job);

    expect(update.status, JobStatus.completed);
    expect(correctPollingHeaders, true);
    expect(correctDownloadHeaders, true);
    expect(downloadAttempted, true);

    final localVideoPath = job.metadata["local_video_path"];
    expect(localVideoPath, isNotNull);

    // 3. Get Result
    final result = await provider.getResult(job.id);
    expect(result.isSuccess, true);
    expect(result.textOutput, localVideoPath);

    final savedFile = File(result.textOutput!);
    expect(await savedFile.exists(), true);
    expect(await savedFile.readAsBytes(), equals(videoBytes));
  });

  test('Operation creation fails with sanitized API key error', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          "error": {
            "message": "Invalid API key test-key and some other info test-key",
          },
        }),
        400,
      );
    });

    final provider = GoogleGeminiVideoProvider(mockContext, client: mockClient);

    final request = ExecutionRequest(
      capability: CapabilityType.videoGeneration,
      input: 'A flying bird',
      parameters: {'imagePath': dummyImageFile.path},
    );

    final job = await provider.execute(request);

    expect(job.status, JobStatus.failed);
    expect(job.error, isNotNull);
    expect(job.error!.message.contains('test-key'), false);
    expect(job.error!.message.contains('[REDACTED_API_KEY]'), true);
  });

  test('Job cancellation correctly handled', () async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({"name": "operations/test-123"}), 200);
    });

    final provider = GoogleGeminiVideoProvider(mockContext, client: mockClient);

    final request = ExecutionRequest(
      capability: CapabilityType.videoGeneration,
      input: 'A flying bird',
      parameters: {'imagePath': dummyImageFile.path},
    );

    final job = await provider.execute(request);
    expect(job.status, JobStatus.queued);

    await provider.cancelJob(job.id);

    final update = await provider.updateJobStatus(job);
    expect(update.status, JobStatus.cancelled);
  });

  test('Download fails gracefully with empty bytes', () async {
    final operationName = 'operations/test-123';
    final videoUri = 'https://example.com/video.mp4';

    final mockClient = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({"name": operationName}), 200);
      } else if (request.method == 'GET' &&
          request.url.toString().contains(operationName)) {
        return http.Response(
          jsonEncode({
            "name": operationName,
            "done": true,
            "response": {
              "generateVideoResponse": {
                "generatedSamples": [
                  {
                    "video": {"uri": videoUri},
                  },
                ],
              },
            },
          }),
          200,
        );
      } else if (request.method == 'GET' &&
          request.url.toString() == videoUri) {
        return http.Response.bytes([], 200); // Empty bytes
      }
      return http.Response('Not Found', 404);
    });

    final provider = GoogleGeminiVideoProvider(mockContext, client: mockClient);

    final request = ExecutionRequest(
      capability: CapabilityType.videoGeneration,
      input: 'A flying bird',
      parameters: {'imagePath': dummyImageFile.path},
    );

    final job = await provider.execute(request);

    final update = await provider.updateJobStatus(job);
    expect(update.status, JobStatus.failed);
    expect(update.error?.message, "Downloaded video is empty");
  });
}
