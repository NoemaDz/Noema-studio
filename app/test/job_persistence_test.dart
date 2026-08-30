import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';

void main() {
  group('Job Serialization', () {
    test('toJson/fromJson preserves all new states', () {
      for (final status in JobStatus.values) {
        final job = Job(
          id: 'test-${status.name}',
          providerId: 'comfyui',
          type: 'image',
          status: status,
          progress: 0.5,
          result: 'some_result',
          metadata: {'prompt': 'test prompt'},
        );

        final json = job.toJson();
        final restored = Job.fromJson(json);

        expect(restored.id, job.id);
        expect(restored.providerId, job.providerId);
        expect(restored.type, job.type);
        expect(restored.status, status, reason: 'Failed for status: $status');
        expect(restored.progress, job.progress);
        expect(restored.result, job.result);
        expect(restored.metadata['prompt'], 'test prompt');
      }
    });

    test('fromJson handles unknown status gracefully', () {
      final json = {
        'id': 'test-unknown',
        'providerId': 'comfyui',
        'type': 'image',
        'status': 'some_future_status_that_does_not_exist',
        'progress': 0.0,
      };

      final job = Job.fromJson(json);
      // Should fall back to pending instead of crashing
      expect(job.status, JobStatus.pending);
    });

    test('fromJson handles null status gracefully', () {
      final json = {
        'id': 'test-null',
        'providerId': 'comfyui',
        'type': 'image',
      };

      final job = Job.fromJson(json);
      expect(job.status, JobStatus.pending);
    });
  });

  group('JobManager Persistence', () {
    test('snapshotActiveJobs returns only non-terminal jobs', () {
      final manager = JobManager();
      manager.add(
        Job(id: '1', providerId: 'p', type: 'image', status: JobStatus.running),
      );
      manager.add(
        Job(
          id: '2',
          providerId: 'p',
          type: 'image',
          status: JobStatus.completed,
        ),
      );
      manager.add(
        Job(id: '3', providerId: 'p', type: 'image', status: JobStatus.failed),
      );
      manager.add(
        Job(id: '4', providerId: 'p', type: 'image', status: JobStatus.queued),
      );
      manager.add(
        Job(
          id: '5',
          providerId: 'p',
          type: 'image',
          status: JobStatus.cancelled,
        ),
      );

      final snapshot = manager.snapshotActiveJobs();

      expect(snapshot.length, 2); // only '1' (running) and '4' (queued)
      expect(snapshot.map((j) => j.id).toSet(), {'1', '4'});
    });

    test('restoreJobs skips duplicates', () {
      final manager = JobManager();
      manager.add(Job(id: '1', providerId: 'p', type: 'image'));

      // Try to restore a job with the same id
      manager.restoreJobs([
        Job(id: '1', providerId: 'p', type: 'image'),
        Job(id: '2', providerId: 'p', type: 'image'),
      ]);

      expect(manager.jobs.length, 2); // '1' (original) + '2' (new)
    });

    test('round-trip: snapshot -> serialize -> deserialize -> restore', () {
      final manager = JobManager();
      manager.add(
        Job(
          id: 'abc',
          providerId: 'comfyui',
          type: 'image',
          status: JobStatus.running,
        ),
      );
      manager.add(
        Job(
          id: 'def',
          providerId: 'comfyui',
          type: 'video',
          status: JobStatus.queued,
        ),
      );
      manager.add(
        Job(
          id: 'ghi',
          providerId: 'comfyui',
          type: 'image',
          status: JobStatus.completed,
        ),
      );

      // Step 1: Snapshot active jobs
      final snapshot = manager.snapshotActiveJobs();
      expect(snapshot.length, 2);

      // Step 2: Serialize to JSON
      final jsonList = snapshot.map((j) => j.toJson()).toList();

      // Step 3: Deserialize from JSON
      final restoredJobs = jsonList.map((j) => Job.fromJson(j)).toList();

      // Step 4: Restore into a new manager (simulating app restart)
      final newManager = JobManager();
      newManager.restoreJobs(restoredJobs);

      expect(newManager.jobs.length, 2);
      expect(newManager.find('abc')?.status, JobStatus.running);
      expect(newManager.find('def')?.status, JobStatus.queued);
      expect(
        newManager.find('ghi'),
        isNull,
      ); // completed should NOT be restored
    });
  });
}
