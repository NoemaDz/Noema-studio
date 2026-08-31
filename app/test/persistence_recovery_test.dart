import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/artifact.dart';
import 'package:noema_studio/models/artifact_type.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/models/project_task.dart';
import 'package:noema_studio/models/task.dart';
import 'package:noema_studio/models/task_status.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';

void main() {
  group('Project Persistence and Recovery', () {
    test('Artifacts survive serialization round-trip', () {
      final project = NoemaProject(
        id: '123',
        idea: 'Test Idea',
        story: Story(title: 'Test Story', scenes: []),
      );

      final artifact = Artifact(
        id: 'art-1',
        path: '/tmp/test.mp4',
        type: ArtifactType.video,
      );

      project.artifacts.add(artifact);

      // Serialize
      final json = project.toJson();

      // Deserialize
      final recoveredProject = NoemaProject.fromJson(json);

      // Verify
      expect(recoveredProject.artifacts.length, 1);
      expect(recoveredProject.artifacts.first.id, 'art-1');
      expect(recoveredProject.artifacts.first.path, '/tmp/test.mp4');
      expect(recoveredProject.artifacts.first.type, ArtifactType.video);
    });

    test(
      'NoemaProject.fromJson intercepts running tasks and marks them failed',
      () {
        final task = ProjectTask(
          type: TaskType.generateStory,
          status: TaskStatus.running,
        );

        final project = NoemaProject(
          id: '123',
          idea: 'Test Idea',
          story: Story(title: 'Test Story', scenes: []),
        );
        project.tasks.add(task);

        final json = project.toJson();

        // The recovered project should have the task marked as failed
        // due to the reconciliation logic checking for abandoned running tasks
        final recoveredProject = NoemaProject.fromJson(json);

        expect(recoveredProject.tasks.length, 1);
        expect(recoveredProject.tasks.first.status, TaskStatus.failed);
        expect(
          recoveredProject.tasks.first.message,
          'Task interrupted by application restart',
        );
      },
    );

    test(
      'JobManager.restoreJobs intercepts running/queued jobs and marks them failed',
      () {
        final jobManager = JobManager();

        final runningJob = Job(
          id: 'j1',
          providerId: 'p1',
          type: 't1',
          status: JobStatus.running,
        );
        final queuedJob = Job(
          id: 'j2',
          providerId: 'p2',
          type: 't2',
          status: JobStatus.queued,
        );
        final completedJob = Job(
          id: 'j3',
          providerId: 'p3',
          type: 't3',
          status: JobStatus.completed,
        );

        jobManager.restoreJobs([runningJob, queuedJob, completedJob]);

        final restoredRunningJob = jobManager.find('j1');
        final restoredQueuedJob = jobManager.find('j2');
        final restoredCompletedJob = jobManager.find('j3');

        // Check reconciliation logic
        expect(restoredRunningJob?.status, JobStatus.failed);
        expect(restoredRunningJob?.error?.code, 'app_restart');

        expect(restoredQueuedJob?.status, JobStatus.failed);
        expect(restoredQueuedJob?.error?.code, 'app_restart');

        expect(restoredCompletedJob?.status, JobStatus.completed);
      },
    );
  });
}
