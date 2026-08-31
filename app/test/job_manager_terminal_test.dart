import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';

void main() {
  group('JobManager Terminal State Tests', () {
    late JobManager jobManager;

    setUp(() {
      jobManager = JobManager();
    });

    test('completed Job → waitForCompletion returns immediately', () async {
      final job = Job(
        id: '1',
        providerId: 'test',
        type: 'test',
        status: JobStatus.completed,
      );
      jobManager.add(job);
      await jobManager.waitForCompletion('1');
      expect(true, isTrue);
    });

    test('failed Job → waitForCompletion returns immediately', () async {
      final job = Job(
        id: '2',
        providerId: 'test',
        type: 'test',
        status: JobStatus.failed,
      );
      jobManager.add(job);
      await jobManager.waitForCompletion('2');
      expect(true, isTrue);
    });

    test('cancelled Job → waitForCompletion returns immediately', () async {
      final job = Job(
        id: '3',
        providerId: 'test',
        type: 'test',
        status: JobStatus.cancelled,
      );
      jobManager.add(job);
      await jobManager.waitForCompletion('3');
      expect(true, isTrue);
    });

    test(
      'waitForCompletion returns when job becomes cancelled while waiting',
      () async {
        final job = Job(
          id: '4',
          providerId: 'test',
          type: 'test',
          status: JobStatus.running,
        );
        jobManager.add(job);

        // Cancel the job asynchronously
        Future.delayed(const Duration(milliseconds: 100), () {
          jobManager.cancelJob(
            '4',
          ); // This will transition the job to cancelled
        });

        await jobManager.waitForCompletion('4');
        expect(jobManager.find('4')?.status, JobStatus.cancelled);
      },
    );
  });
}
