import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/job_monitor.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/job_runner.dart';
import 'package:noema_studio/core/job_events.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/providers/async_provider.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/contracts/execution_result.dart';
import 'package:noema_studio/core/capabilities/capability.dart';

class TimeoutMockProvider extends AsyncProvider {
  @override
  final String id = 'timeout_mock';
  @override
  String get name => "Mock Provider";
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {};
  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  bool wasCancelled = false;
  JobStatus returnStatus = JobStatus.running;

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    return JobStatusUpdate(status: returnStatus);
  }

  @override
  Future<void> cancelJob(String jobId) async {
    wasCancelled = true;
  }

  @override
  Future<Job> execute(ExecutionRequest request) async =>
      throw UnimplementedError();

  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      throw UnimplementedError();
}

void main() {
  group('JobMonitor Timeout Semantics Tests', () {
    late ProviderRegistry registry;
    late JobRunner runner;
    late JobManager manager;
    late JobEvents events;
    late TimeoutMockProvider provider;

    setUp(() {
      registry = ProviderRegistry();
      runner = JobRunner(registry);
      manager = JobManager(registry: registry);
      events = JobEvents();
      provider = TimeoutMockProvider();
      registry.register(provider);
    });

    test(
      'timeout triggers provider cancellation and reaches failed state',
      () async {
        final monitor = JobMonitor(
          runner,
          manager,
          events,
          timeoutDuration: const Duration(seconds: 1),
        );

        final job = Job(
          id: '1',
          providerId: 'timeout_mock',
          type: 'image',
          status: JobStatus.running,
        );
        manager.add(job);

        // Manually simulate startedAt way in the past to trigger timeout
        job.startedAt = DateTime.now().subtract(const Duration(minutes: 10));

        // Perform one tick manually instead of starting the timer
        // We have to simulate what JobMonitor does inside the timer
        final duration = DateTime.now().difference(job.startedAt!);
        if (duration > monitor.timeoutDuration) {
          await manager.cancelJob(
            job.id,
            finalStatus: JobStatus.failed,
            error: JobError(
              code: 'TIMEOUT',
              message:
                  'Job exceeded maximum execution time of ${monitor.timeoutDuration.inMinutes} minutes.',
            ),
          );
        }

        expect(provider.wasCancelled, isTrue);
        expect(job.status, JobStatus.failed);
        expect(job.error?.code, 'TIMEOUT');
      },
    );

    test(
      'queued timeout triggers provider cancellation and reaches failed state',
      () async {
        JobMonitor(runner, manager, events);

        final job = Job(
          id: '1',
          providerId: 'timeout_mock',
          type: 'image',
          status: JobStatus.queued,
          createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
        );
        manager.add(job);

        final queuedDuration = DateTime.now().difference(job.createdAt);
        if (queuedDuration > const Duration(minutes: 30)) {
          await manager.cancelJob(
            job.id,
            finalStatus: JobStatus.failed,
            error: JobError(
              code: 'QUEUED_TIMEOUT',
              message: 'Job was stuck in queue for too long.',
            ),
          );
        }

        expect(
          provider.wasCancelled,
          isTrue,
        ); // Queued jobs might not have been sent to provider, but we attempt cancel anyway
        expect(job.status, JobStatus.failed);
        expect(job.error?.code, 'QUEUED_TIMEOUT');
      },
    );

    test(
      'timeout + completion race (completed status arrives right before timeout applies)',
      () async {
        JobMonitor(
          runner,
          manager,
          events,
          timeoutDuration: const Duration(seconds: 1),
        );

        final job = Job(
          id: '1',
          providerId: 'timeout_mock',
          type: 'image',
          status: JobStatus.running,
        );
        manager.add(job);

        job.startedAt = DateTime.now().subtract(
          const Duration(minutes: 10),
        ); // Timeout condition met

        // Simulate completion arriving first
        manager.applyUpdate(
          '1',
          JobStatusUpdate(status: JobStatus.completed, progress: 1.0),
        );

        // Now timeout logic runs
        if (job.status != JobStatus.completed &&
            job.status != JobStatus.failed &&
            job.status != JobStatus.cancelled) {
          await manager.cancelJob('1', finalStatus: JobStatus.failed);
        } else {
          // cancelJob internally checks if it's already terminal
          await manager.cancelJob('1', finalStatus: JobStatus.failed);
        }

        // Because it was already completed, cancelJob should do nothing
        expect(job.status, JobStatus.completed);
        expect(provider.wasCancelled, isFalse);
      },
    );

    test(
      'timeout cannot result in a later completed Job (terminal state enforces immutability)',
      () async {
        final job = Job(
          id: '1',
          providerId: 'timeout_mock',
          type: 'image',
          status: JobStatus.running,
        );
        manager.add(job);

        // Timeout occurs
        await manager.cancelJob(
          job.id,
          finalStatus: JobStatus.failed,
          error: JobError(code: 'TIMEOUT', message: 'Timeout'),
        );

        expect(job.status, JobStatus.failed);

        // Provider later responds with completed
        manager.applyUpdate(
          '1',
          JobStatusUpdate(status: JobStatus.completed, progress: 1.0),
        );

        // Status must remain failed
        expect(job.status, JobStatus.failed);
      },
    );
  });
}
