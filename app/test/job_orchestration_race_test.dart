import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/job_runner.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_provider.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/models/job.dart';
import 'dart:async';

// Mock dependencies
import 'comfyui_failure_injection_test.dart'
    show MockComfyUIDriver, MockPluginContext;

void main() {
  group('Job Orchestration Race Conditions', () {
    late JobManager manager;
    late ProviderRegistry registry;
    late ComfyUIProvider provider;
    late MockComfyUIDriver driver;

    setUp(() {
      driver = MockComfyUIDriver();
      provider = ComfyUIProvider(MockPluginContext(), driver: driver);
      registry = ProviderRegistry();
      registry.register(provider);
      manager = JobManager(registry: registry);

      // We manually instantiate JobRunner to simulate race ticks
      // JobManager creates its own JobRunner, but for testing race conditions
      // precisely, we manipulate the manager and runner states explicitly.
    });

    test(
      'Cancellation Race: Late result after cancellation is ignored',
      () async {
        final request = ExecutionRequest(
          capability: CapabilityType.imageGeneration,
          input: 'test',
        );

        // Submit job
        final job = await provider.execute(request);
        manager.add(job);
        manager.updateStatus(job.id, JobStatus.running);

        // Simulate the provider's HTTP call taking a long time to poll
        final completer = Completer<JobStatusUpdate>();
        driver.onUpdateJobStatus = (j) => completer.future;

        // Start the update process
        final updateFuture = provider.updateJobStatus(job);

        // Meanwhile, the user cancels the job
        await manager.cancelJob(job.id);
        expect(job.status, JobStatus.cancelled);

        // Now the delayed HTTP call returns success (late callback)
        completer.complete(JobStatusUpdate(status: JobStatus.completed));
        final update = await updateFuture;

        // The runner tries to apply the late update
        manager.applyUpdate(job.id, update);

        // The job MUST remain cancelled, project must not be corrupted
        expect(job.status, JobStatus.cancelled);
      },
    );

    test('Duplicate Result: Idempotency check', () async {
      final request = ExecutionRequest(
        capability: CapabilityType.imageGeneration,
        input: 'test',
      );

      final job = await provider.execute(request);
      manager.add(job);
      manager.updateStatus(job.id, JobStatus.running);

      // First completion update
      manager.applyUpdate(job.id, JobStatusUpdate(status: JobStatus.completed));
      expect(job.status, JobStatus.completed);

      // Duplicate completion update arrives
      manager.applyUpdate(job.id, JobStatusUpdate(status: JobStatus.completed));

      // Status remains complete, no crash
      expect(job.status, JobStatus.completed);
    });
  });
}
