import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/providers/async_provider.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/contracts/execution_result.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/application/project_synchronizer.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/presentation/state/project_state.dart';

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

  bool wasCancelled = false;

  MockProvider(this.id);

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    return JobStatusUpdate(status: JobStatus.running);
  }

  @override
  Future<void> cancelJob(String jobId) async {
    wasCancelled = true;
  }

  @override
  Future<Job> execute(ExecutionRequest request) async =>
      throw UnimplementedError();

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    return ExecutionResult.success(textOutput: '/path/to/result.png');
  }
}

void main() {
  late ProviderRegistry registry;
  late JobManager manager;
  late MockProvider provider;

  setUp(() {
    registry = ProviderRegistry();
    manager = JobManager(registry: registry);
    provider = MockProvider('mock_provider');
    registry.register(provider);
  });

  group('JobManager Integration and Resource Leak Prevention', () {
    test(
      'clear() cancels active jobs to prevent engine resource leaks (VRAM)',
      () async {
        final job = Job(
          id: '1',
          providerId: 'mock_provider',
          type: 'image',
          status: JobStatus.running,
        );
        manager.add(job);

        expect(provider.wasCancelled, isFalse);

        // Act
        manager.clear();

        // Assert: The backend provider should have been asked to cancel the job, freeing VRAM.
        // Since clear() fires cancelJob asynchronously, we yield once to let the future start.
        await Future.delayed(Duration.zero);
        expect(provider.wasCancelled, isTrue);
        expect(manager.jobs.isEmpty, isTrue);
      },
    );
  });

  group('ProjectSynchronizer Integration', () {
    test(
      'ignores events for jobs belonging to other projects (cross-project contamination prevention)',
      () async {
        final project = NoemaProject(
          id: 'proj1',
          idea: 'test',
          story: Story(title: 'test', scenes: []),
        );
        project.jobIds.add('job1');

        final state = ProjectState();
        state.setProject(project);

        final synchronizer = ProjectSynchronizer(
          project: project,
          registry: registry,
          state: state,
          jobManager: manager,
          saveProject: (p) async {},
        );

        // Event for the current project
        final myJob = Job(
          id: 'job1',
          providerId: 'mock_provider',
          type: 'image',
          status: JobStatus.running,
        );

        // Event for an old project that was somehow emitted
        final foreignJob = Job(
          id: 'job2',
          providerId: 'mock_provider',
          type: 'image',
          status: JobStatus.running,
        );

        manager.add(myJob);
        manager.add(foreignJob);

        // We spy on the method indirectly. If the job is processed, it adds to savedJobs.
        await synchronizer.synchronize(foreignJob);
        // It should instantly return without updating savedJobs.
        expect(project.savedJobs.isEmpty, isTrue);

        await synchronizer.synchronize(myJob);
        // It should process myJob and update savedJobs with all active jobs in the manager (2 jobs)
        expect(project.savedJobs.length, equals(2));
      },
    );
  });
}
