import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/application/services/document_ingestion_service.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/contracts/execution_result.dart';
import 'package:noema_studio/core/job_events.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/core/providers/document_ingestion_provider.dart';
import 'package:noema_studio/core/providers/image_provider.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/workflow/workflow_context.dart';
import 'package:noema_studio/core/pipeline/project_pipeline.dart';
import 'package:noema_studio/core/pipeline/pipeline_registry.dart';
import 'package:noema_studio/core/pipeline/pipeline_engine.dart';
import 'package:noema_studio/application/project_synchronizer.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/cancellation_token.dart';
import 'package:noema_studio/presentation/state/project_state.dart';
import 'package:noema_studio/workflows/character_images/generate_character_images_step.dart';
import 'package:noema_studio/models/character.dart';
import 'package:noema_studio/models/story.dart';

// Mocks

class MockImageProvider extends ImageProvider {
  int executeCallCount = 0;
  int cancelCallCount = 0;
  Completer<void>? jobCompleter;

  @override
  String get id => 'mock_image';
  @override
  String get name => 'Mock Image';
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};
  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  @override
  Future<Job> execute(ExecutionRequest request) async {
    executeCallCount++;
    final job = Job(
      id: 'img_job_$executeCallCount',
      providerId: id,
      type: 'image',
      status: JobStatus.running,
    );
    // Simulate long running job
    jobCompleter?.future.then((_) {
      if (job.status == JobStatus.running) {
        job.transitionTo(JobStatus.completed);
      }
    });
    return job;
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async =>
      JobStatusUpdate(status: job.status);

  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      ExecutionResult.success(textOutput: 'mock.png');

  @override
  Future<void> cancelJob(String jobId) async {
    cancelCallCount++;
  }
}

class MockIngestionProvider extends DocumentIngestionProvider {
  int executeCallCount = 0;
  int cancelCallCount = 0;
  Completer<void>? jobCompleter;

  @override
  String get id => 'mock_ingest';
  @override
  String get name => 'Mock Ingest';
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {CapabilityType.llm};
  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();
  @override
  List<String> get supportedExtensions => ['pdf', 'txt'];

  @override
  Future<String> readText(String filePath) async => 'mock text';

  @override
  Future<Job> execute(ExecutionRequest request) async {
    executeCallCount++;
    final job = Job(
      id: 'ingest_job_$executeCallCount',
      providerId: id,
      type: 'ingestion',
      status: JobStatus.running,
    );
    jobCompleter?.future.then((_) {
      if (job.status == JobStatus.running) {
        job.transitionTo(JobStatus.completed);
      }
    });
    return job;
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async =>
      JobStatusUpdate(status: job.status);

  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      ExecutionResult.success(textOutput: 'mock text');

  @override
  Future<void> cancelJob(String jobId) async {
    cancelCallCount++;
  }
}

class MockProjectState extends ProjectState {
  int refreshCallCount = 0;
  @override
  void refresh() {
    refreshCallCount++;
  }
}

void main() {
  group('Production Readiness Regression Tests', () {
    late JobManager jobManager;
    late JobEvents jobEvents;
    late ProviderRegistry registry;
    late MockImageProvider imageProvider;
    late MockIngestionProvider ingestProvider;

    setUp(() {
      jobEvents = JobEvents();
      registry = ProviderRegistry();

      imageProvider = MockImageProvider();
      ingestProvider = MockIngestionProvider();

      registry.register(imageProvider);
      registry.register(ingestProvider);

      jobManager = JobManager(registry: registry);
    });

    tearDown(() {
      jobManager.dispose();
    });

    test('1. GenerateCharacterImagesStep - Cancellation', () async {
      imageProvider.jobCompleter = Completer<void>(); // Keeps job running
      final step = GenerateCharacterImagesStep(imageProvider);

      final project = NoemaProject(
        id: 'test',
        idea: 'test idea',
        story: Story(title: 'test', scenes: []),
      );
      project.characters.add(
        Character(
          id: 'c1',
          name: 'Test',
          description: 'desc',
          prompt: 'a test',
        ),
      );

      final context = WorkflowContext();
      context.set('project', project);
      context.set('jobManager', jobManager);

      final token = CancellationToken();
      context.set('cancellationToken', token);

      final executeFuture = step.execute(context);

      // Wait for job to be spawned
      await Future.delayed(const Duration(milliseconds: 50));
      expect(imageProvider.executeCallCount, 1);

      final jobId = project.jobIds.first;
      final job = jobManager.find(jobId)!;
      expect(job.status, JobStatus.running);

      // Cancel
      token.cancel();

      await expectLater(executeFuture, throwsA(isA<CancelledException>()));

      // Give time for catch block to execute jobManager.cancelJob
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify cancellation
      expect(imageProvider.cancelCallCount, 1);
      expect(job.status, JobStatus.cancelled);
    });

    test('2. DocumentIngestionService - Cancellation', () async {
      ingestProvider.jobCompleter = Completer<void>();

      final service = DocumentIngestionService(registry, jobManager);
      final token = CancellationToken();

      final importFuture = service.importDocument('test.pdf', token: token);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(ingestProvider.executeCallCount, 1);

      final job = jobManager.jobs.first;
      expect(job.status, JobStatus.running);

      token.cancel();

      await expectLater(importFuture, throwsA(isA<CancelledException>()));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(ingestProvider.cancelCallCount, 1);
      expect(job.status, JobStatus.cancelled);
    });

    test(
      '3. ProjectPipeline - Regeneration with queued/non-terminal Job',
      () async {
        final pipeline = ProjectPipeline(
          registry: PipelineRegistry(),
          jobManager: jobManager,
          engine: PipelineEngine(
            maxConcurrentTasks: 1,
            maxConcurrentGPUTasks: 1,
          ),
        );

        final project = NoemaProject(
          id: 'test',
          idea: 'idea',
          story: Story(title: 'test', scenes: []),
        );

        // Create a queued job
        final job = Job(
          id: 'queued_job',
          providerId: imageProvider.id,
          type: 'image',
          status: JobStatus.queued,
        );
        jobManager.add(job);
        project.jobIds.add(job.id);

        // Execute generateProduction
        await pipeline.generateProduction(project);

        // Verify job was removed and cancelled
        expect(jobManager.jobs.isEmpty, true);
        expect(project.jobIds.isEmpty, true);
        expect(imageProvider.cancelCallCount, 1);
      },
    );

    test('4. ProjectSynchronizer - Cancellation Persistence', () async {
      final project = NoemaProject(
        id: 'test',
        idea: 'idea',
        story: Story(title: 'test', scenes: []),
      );
      final state = MockProjectState();

      int saveCount = 0;
      void saveProject(NoemaProject p) {
        saveCount++;
      }

      final synchronizer = ProjectSynchronizer(
        project: project,
        registry: ProviderRegistry(),
        state: state,
        jobManager: jobManager,
        saveProject: saveProject,
      );

      final job = Job(
        id: 'running_job',
        providerId: 'mock',
        type: 'image',
        status: JobStatus.running,
      );
      jobManager.add(job);
      project.jobIds.add(job.id);

      await synchronizer.attach(jobEvents);

      // Wait for attach to process pre-existing jobs
      await Future.delayed(const Duration(milliseconds: 50));

      // Change to cancelled and emit
      job.forceStatus(JobStatus.cancelled);
      jobEvents.emit(job);

      // Wait for stream to process
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify saveProject was called
      expect(saveCount, 1);
      expect(state.refreshCallCount, 1);

      // Verify it is not in savedJobs
      expect(project.savedJobs.any((j) => j.id == job.id), false);

      synchronizer.dispose();
    });
  });
}
