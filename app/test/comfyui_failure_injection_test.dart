import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/plugins/plugin_context.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/settings/app_settings.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_provider.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_driver.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/core/hardware/hardware_service.dart';
import 'package:noema_studio/core/workflow/workflow_engine.dart';
import 'package:noema_studio/core/pipeline/pipeline_registry.dart';
import 'package:noema_studio/core/capabilities/capability_resolver.dart';

class MockAppSettings extends AppSettings {
  @override
  String get comfyUIUrl => 'http://localhost:8188';
  @override
  PerformanceProfile get performanceMode => PerformanceProfile.balanced;
}

class MockPluginContext implements PluginContext {
  @override
  final AppSettings appSettings = MockAppSettings();

  @override
  dynamic get database => throw UnimplementedError();

  @override
  CapabilityResolver get capabilityResolver => throw UnimplementedError();

  @override
  WorkflowEngine get engine => throw UnimplementedError();

  @override
  JobManager get jobManager => throw UnimplementedError();

  @override
  PipelineRegistry get pipelines => throw UnimplementedError();

  @override
  ProviderRegistry get providers => throw UnimplementedError();
}

class MockComfyUIDriver implements ComfyUIDriver {
  @override
  PluginContext get context => MockPluginContext();

  @override
  String get baseUrl => context.appSettings.comfyUIUrl;

  Future<Job> Function(String prompt, {Map<String, dynamic>? options})?
  onSubmitJob;
  Future<JobStatusUpdate> Function(Job job)? onUpdateJobStatus;

  @override
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) async {
    if (onSubmitJob != null) {
      return onSubmitJob!(prompt, options: options);
    }
    return Job(
      id: 'job123',
      providerId: 'comfyui',
      type: 'image',
      status: JobStatus.queued,
    );
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    if (onUpdateJobStatus != null) {
      return onUpdateJobStatus!(job);
    }
    return JobStatusUpdate(status: JobStatus.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ComfyUI Failure Injection', () {
    late ComfyUIProvider provider;
    late JobManager jobManager;
    late MockComfyUIDriver mockDriver;

    setUp(() {
      final context = MockPluginContext();
      mockDriver = MockComfyUIDriver();
      provider = ComfyUIProvider(context, driver: mockDriver);

      final registry = ProviderRegistry();
      registry.register(provider);
      jobManager = JobManager(registry: registry);
    });

    test('Submission failure propagates to exception', () async {
      mockDriver.onSubmitJob = (prompt, {options}) async {
        throw Exception('ComfyUI API returned 500: Internal Server Error');
      };

      final request = ExecutionRequest(
        capability: CapabilityType.imageGeneration,
        input: 'test prompt',
      );

      await expectLater(
        () => provider.execute(request),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('ComfyUI API returned 500'),
          ),
        ),
      );
    });

    test(
      'Generation failure (polling returns error) makes Job FAILED',
      () async {
        mockDriver.onUpdateJobStatus = (job) async {
          return JobStatusUpdate(
            status: JobStatus.failed,
            error: JobError(
              code: 'COMFYUI_ERROR',
              message: 'CUDA out of memory',
            ),
          );
        };

        final request = ExecutionRequest(
          capability: CapabilityType.imageGeneration,
          input: 'test prompt',
        );

        final job = await provider.execute(request);
        jobManager.add(job);

        // The JobRunner updates status. We simulate a tick.
        final update = await provider.updateJobStatus(job);
        expect(update.status, JobStatus.failed);
        expect(update.error?.message, contains('CUDA out of memory'));
      },
    );

    test('Polling returns 404/not found fails Job with NOT_FOUND', () async {
      mockDriver.onUpdateJobStatus = (job) async {
        return JobStatusUpdate(
          status: JobStatus.failed,
          error: JobError(
            code: 'COMFYUI_NOT_FOUND',
            message: 'Job not found in ComfyUI queue',
          ),
        );
      };

      final request = ExecutionRequest(
        capability: CapabilityType.imageGeneration,
        input: 'test prompt',
      );

      final job = await provider.execute(request);
      jobManager.add(job);

      JobStatusUpdate update = await provider.updateJobStatus(job);
      expect(update.status, JobStatus.failed);
      expect(update.error?.code, 'COMFYUI_NOT_FOUND');
    });

    test(
      'Backend timeout during updateJobStatus throws exception to allow retry',
      () async {
        mockDriver.onUpdateJobStatus = (job) async {
          throw const SocketException('Connection refused');
        };

        final job = Job(
          id: 'job123',
          providerId: 'comfyui',
          type: 'image',
          status: JobStatus.running,
        );

        await expectLater(
          () => provider.updateJobStatus(job),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Connection refused'),
            ),
          ),
        );
      },
    );
  });
}
