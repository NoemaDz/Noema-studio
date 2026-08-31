import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/infrastructure/ingestion/txt_reader.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';

void main() {
  group('DocumentIngestion ExecutionContract', () {
    late JobManager jobManager;

    setUp(() {
      jobManager = JobManager();
    });

    test(
      'TxtReader executes and JobManager handles lifecycle deterministically',
      () async {
        final reader = TxtReader();
        final tempFile = File('test_ingest.txt');
        await tempFile.writeAsString('Hello Noema');

        final request = ExecutionRequest(
          capability: CapabilityType.llm,
          input: '',
          parameters: {'file_path': tempFile.path},
        );

        final job = await reader.execute(request);
        jobManager.add(job);
        expect(jobManager.find(job.id)?.status, JobStatus.running);

        // Wait for microtask to complete ingestion
        await Future.delayed(const Duration(milliseconds: 100));

        // We apply update just like JobRunner would
        final update = await reader.updateJobStatus(job);
        jobManager.applyUpdate(job.id, update);

        // Now we wait for completion (returns instantly since it's already completed)
        await jobManager.waitForCompletion(job.id);
        expect(jobManager.find(job.id)?.status, JobStatus.completed);

        final result = await reader.getResult(job.id);
        expect(result.isSuccess, true);
        expect(result.textOutput, 'Hello Noema');

        await tempFile.delete();
      },
    );

    test(
      'TxtReader returns failure for non-existent file deterministically',
      () async {
        final reader = TxtReader();
        final request = ExecutionRequest(
          capability: CapabilityType.llm,
          input: '',
          parameters: {'file_path': 'does_not_exist.txt'},
        );

        final job = await reader.execute(request);
        jobManager.add(job);

        // Wait for microtask to complete ingestion
        await Future.delayed(const Duration(milliseconds: 100));

        final update = await reader.updateJobStatus(job);
        jobManager.applyUpdate(job.id, update);
        await jobManager.waitForCompletion(job.id);

        expect(jobManager.find(job.id)?.status, JobStatus.failed);

        final result = await reader.getResult(job.id);
        expect(result.isSuccess, false);
        expect(result.error?.code, 'ingestion_failed');
      },
    );

    test(
      'DocumentIngestionService cancellation cannot leave waitForCompletion blocked forever',
      () async {
        final reader = TxtReader();
        final request = ExecutionRequest(
          capability: CapabilityType.llm,
          input: '',
          parameters: {'file_path': 'fake.txt'},
        );

        final job = await reader.execute(request);
        jobManager.add(job);
        expect(jobManager.find(job.id)?.status, JobStatus.running);

        // We cancel the job in the manager
        jobManager.cancelJob(job.id);

        // waitForCompletion should return immediately because of the cancelled state
        // (it will not block forever)
        await jobManager
            .waitForCompletion(job.id)
            .timeout(const Duration(milliseconds: 500));

        expect(jobManager.find(job.id)?.status, JobStatus.cancelled);
      },
    );
  });
}
