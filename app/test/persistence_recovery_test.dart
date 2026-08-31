import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/core/noema.dart';
import 'dart:io';
import 'dart:convert';
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

    test(
      'Integration: save -> simulated crash -> reload -> recovery (Artifact reconciliation)',
      () async {
        final noema = Noema();
        noema.init([]);

        // 1. Create a project with some artifacts, simulating before a crash
        final project = NoemaProject(
          id: 'crash-test',
          idea: 'Crash Recovery',
          story: Story(title: 'T', scenes: []),
        );

        // Add a running job
        project.savedJobs.add(
          Job(
            id: 'job-1',
            providerId: 'p',
            type: 't',
            status: JobStatus.running,
          ),
        );

        // Add two artifacts: one that exists on disk, one that doesn't
        final tempDir = Directory.systemTemp.createTempSync('noema_test');
        final validFile = File('${tempDir.path}/valid.mp4')..createSync();
        final missingFilePath = '${tempDir.path}/missing.mp4'; // Never created

        project.artifacts.add(
          Artifact(id: 'a1', path: validFile.path, type: ArtifactType.video),
        );
        project.artifacts.add(
          Artifact(id: 'a2', path: missingFilePath, type: ArtifactType.video),
        );

        // Simulate saving before crash (bypassing path_provider by directly writing JSON)
        final projectJsonFile = File('${tempDir.path}/project.json');
        projectJsonFile.writeAsStringSync(jsonEncode(project.toJson()));

        // --- SIMULATED CRASH HAPPENS HERE ---

        // 2. Reload and Recovery
        final recoveredProject = await noema.openProject(projectJsonFile.path);

        // 3. Verification

        // Job was recovered and reconciled as failed natively
        expect(noema.bootstrap.jobManager.contains('job-1'), true);
        expect(
          noema.bootstrap.jobManager.find('job-1')?.status,
          JobStatus.failed,
        );

        // Artifacts were reconciled (the missing one should be gone)
        expect(recoveredProject.artifacts.length, 1);
        expect(recoveredProject.artifacts.first.path, validFile.path);

        // Clean up
        tempDir.deleteSync(recursive: true);
      },
    );
  });
}
