import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/job_runner.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/providers/async_provider.dart';
import 'package:noema_studio/models/asset.dart';
import 'package:noema_studio/core/capabilities/capability.dart';

class MockProvider extends AsyncProvider {
  @override
  final String id;

  @override
  String get name => "Mock $id";

  String get version => "1.0";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  int updateCount = 0;
  JobStatus returnStatus = JobStatus.running;
  bool throwError = false;
  bool wasCancelled = false;

  MockProvider(this.id);

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    if (throwError) {
      throw Exception("Provider error");
    }
    updateCount++;
    return JobStatusUpdate(status: returnStatus);
  }

  @override
  Future<void> cancelJob(String jobId) async {
    wasCancelled = true;
  }

  @override
  Future<Asset?> downloadAsset(String jobId) async => null;
}

void main() {
  late ProviderRegistry registry;
  late JobManager manager;
  late JobRunner runner;
  late MockProvider provider;

  setUp(() {
    registry = ProviderRegistry();
    manager = JobManager(registry: registry);
    runner = JobRunner(registry);
    provider = MockProvider('mock_provider');
    registry.register(provider);
  });

  group('Job Lifecycle', () {
    test(
      'Job starts from pending and transitions correctly to completed',
      () async {
        final job = Job(
          id: '1',
          providerId: 'mock_provider',
          type: 'image',
          status: JobStatus.pending,
        );
        manager.add(job);

        expect(job.status, JobStatus.pending);

        manager.updateStatus('1', JobStatus.queued);
        expect(job.status, JobStatus.queued);

        manager.updateStatus('1', JobStatus.running);
        expect(job.status, JobStatus.running);
        expect(job.startedAt, isNotNull);

        manager.updateStatus('1', JobStatus.completed);
        expect(job.status, JobStatus.completed);
        expect(job.completedAt, isNotNull);
      },
    );

    test('Completed cannot be cancelled or transitioned', () {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.completed,
      );
      manager.add(job);

      manager.updateStatus('1', JobStatus.running);
      expect(job.status, JobStatus.completed); // Unchanged

      manager.updateStatus('1', JobStatus.cancelling);
      expect(job.status, JobStatus.completed); // Unchanged
    });

    test('Cancelled cannot transition to completed', () {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.cancelled,
      );
      manager.add(job);

      manager.updateStatus('1', JobStatus.completed);
      expect(job.status, JobStatus.cancelled); // Unchanged
    });

    test('Failed cannot transition to completed', () {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.failed,
      );
      manager.add(job);

      manager.updateStatus('1', JobStatus.completed);
      expect(job.status, JobStatus.failed); // Unchanged
    });
  });

  group('JobRunner and Exceptions', () {
    test('Provider exception retries and eventually fails', () async {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.running,
      );
      manager.add(job);
      provider.throwError = true;

      // 4 failures -> returns null (transient)
      for (int i = 0; i < 4; i++) {
        final update = await runner.update(job);
        expect(update, isNull);
      }

      // 5th failure -> returns JobStatus.failed
      final finalUpdate = await runner.update(job);
      expect(finalUpdate, isNotNull);
      expect(finalUpdate!.status, JobStatus.failed);
      expect(finalUpdate.error?.code, 'MAX_RETRIES_EXCEEDED');

      manager.applyUpdate('1', finalUpdate);
      expect(job.status, JobStatus.failed);
    });
  });

  group('JobManager Cancellation', () {
    test('cancellation during execution stops provider', () async {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.running,
      );
      manager.add(job);

      await manager.cancelJob('1');

      expect(provider.wasCancelled, isTrue);
      expect(job.status, JobStatus.cancelled);
      expect(job.completedAt, isNotNull); // Cancelled is a terminal state
    });

    test('cancellation/completion race condition', () async {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.running,
      );
      manager.add(job);

      // Simulate provider saying completed, but before manager applies it, user cancels.
      provider.returnStatus = JobStatus.completed;
      final update = await runner.update(job); // Returns completed

      await manager.cancelJob('1'); // User cancels -> status becomes cancelled

      manager.applyUpdate('1', update!); // Manager tries to apply completed

      // Since it's cancelled, transition to completed should fail and remain cancelled
      expect(job.status, JobStatus.cancelled);
    });

    test('cancellation/failure race condition', () async {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.running,
      );
      manager.add(job);

      provider.returnStatus = JobStatus.failed;
      final update = await runner.update(job);

      await manager.cancelJob('1');
      manager.applyUpdate('1', update!);

      expect(job.status, JobStatus.cancelled);
    });
  });

  group('Progress Semantics', () {
    test('no progress updates after terminal state', () async {
      final job = Job(
        id: '1',
        providerId: 'mock_provider',
        type: 'image',
        status: JobStatus.running,
      );
      manager.add(job);
      job.progress = 0.5;

      // Force into terminal state
      manager.applyUpdate(
        '1',
        JobStatusUpdate(status: JobStatus.completed, progress: 1.0),
      );
      expect(job.status, JobStatus.completed);
      expect(job.progress, 1.0);

      // Attempt to update progress
      manager.applyUpdate(
        '1',
        JobStatusUpdate(status: JobStatus.completed, progress: 0.8),
      ); // Illegal? No, transitionTo(completed) from completed fails
      expect(job.progress, 1.0);
    });

    test(
      'progress never decreases when real provider progress is supplied',
      () async {
        final job = Job(
          id: '1',
          providerId: 'mock_provider',
          type: 'image',
          status: JobStatus.running,
        );
        manager.add(job);
        job.progress = 0.5;

        // Provide higher progress
        manager.applyUpdate(
          '1',
          JobStatusUpdate(status: JobStatus.running, progress: 0.6),
        );
        expect(job.progress, 0.6);

        // Attempt to decrease progress
        manager.applyUpdate(
          '1',
          JobStatusUpdate(status: JobStatus.running, progress: 0.4),
        );
        // Should remain 0.6
        expect(job.progress, 0.6);
      },
    );
  });
}
