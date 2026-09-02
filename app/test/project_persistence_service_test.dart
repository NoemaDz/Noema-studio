import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/application/project_synchronizer.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/presentation/state/project_state.dart';
import 'package:noema_studio/core/job_events.dart';
import 'dart:async';
import 'dart:io';

void main() {
  group('ProjectSynchronizer Failure Recovery', () {
    test('Stream remains active if saveProject throws an Exception', () async {
      final project = NoemaProject(
        id: '123',
        idea: 'Idea',
        story: Story(title: 'T', scenes: []),
      );

      final jobManager = JobManager();
      final registry = ProviderRegistry();
      final state = ProjectState();
      final events = JobEvents();

      int saveCallCount = 0;

      // Inject a saveProject that throws on the first call, succeeds on the second
      void failingSaveProject(NoemaProject p) {
        saveCallCount++;
        if (saveCallCount == 1) {
          throw const FileSystemException('Disk full');
        }
      }

      final synchronizer = ProjectSynchronizer(
        project: project,
        registry: registry,
        state: state,
        jobManager: jobManager,
        saveProject: failingSaveProject,
      );

      await synchronizer.attach(events);

      Job job1 = Job(
        id: 'j1',
        providerId: 'p',
        type: 't',
        status: JobStatus.running,
      );
      Job job2 = Job(
        id: 'j2',
        providerId: 'p',
        type: 't',
        status: JobStatus.running,
      );

      project.jobIds.add('j1');
      project.jobIds.add('j2');

      jobManager.add(job1);
      jobManager.add(job2);

      // Trigger first update - saveProject throws
      job1.forceStatus(JobStatus.failed);
      events.emit(job1);

      // Wait a tiny bit for the stream to process
      await Future.delayed(const Duration(milliseconds: 50));

      expect(saveCallCount, 1);
      expect(project.savedJobs.length, 1);
      // The remaining active job is job2 which is running
      expect(project.savedJobs.first.status, JobStatus.running);
      expect(project.savedJobs.first.id, 'j2');

      // Trigger second update - saveProject succeeds
      // If the stream broke, saveCallCount will remain 1
      job2.forceStatus(JobStatus.failed);
      events.emit(job2);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(saveCallCount, 2);
      expect(project.savedJobs.length, 0); // Both jobs are terminal now

      synchronizer.dispose();
    });
  });
}
