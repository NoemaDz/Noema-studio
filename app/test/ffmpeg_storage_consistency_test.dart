import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/infrastructure/mock/mock_video_compiler_provider.dart';
import 'package:noema_studio/models/artifact.dart';
import 'package:noema_studio/models/artifact_type.dart';

void main() {
  group('FFmpeg Storage Consistency & Job State', () {
    late JobManager jobManager;

    setUp(() {
      jobManager = JobManager();
    });

    test(
      'Artifact persistence happens before Job completion in application flow',
      () async {
        final provider = MockVideoCompilerProvider();
        final artifacts = <Artifact>[];

        final request = ExecutionRequest(
          capability: CapabilityType.videoGeneration,
          input: 'Test compile',
          parameters: {'output_path': 'final_output.mp4'},
        );

        final job = await provider.execute(request);
        jobManager.add(job);

        // Since it's a mock, it's done immediately, so we can await getResult
        final result = await provider.getResult(job.id);
        expect(result.isSuccess, true);
        expect(result.textOutput, isNotNull);

        // The Job MUST still be running here!
        expect(jobManager.find(job.id)?.status, JobStatus.running);

        // Application creates/persists the artifact BEFORE completing Job
        final artifact = Artifact(
          id: job.id,
          path: result.textOutput!,
          type: ArtifactType.video,
        );
        artifacts.add(artifact);
        expect(artifacts.contains(artifact), true);

        // Application completes the job
        jobManager.complete(job.id, artifact.path);
        expect(jobManager.find(job.id)?.status, JobStatus.completed);
        expect(jobManager.find(job.id)?.result, artifact.path);
      },
    );

    test('Missing output cannot produce a completed Job', () async {
      final provider = MockVideoCompilerProvider();

      final request = ExecutionRequest(
        capability: CapabilityType.videoGeneration,
        input: 'Test compile',
        parameters: {
          'output_path': 'final_output.mp4',
          'simulate_failure': true,
        },
      );

      final job = await provider.execute(request);
      jobManager.add(job);

      final result = await provider.getResult(job.id);
      expect(result.isSuccess, false);

      // The Job MUST still be running here!
      expect(jobManager.find(job.id)?.status, JobStatus.running);

      // Application fails the job
      jobManager.fail(
        job.id,
        result.error ?? JobError(code: 'err', message: 'err'),
      );
      expect(jobManager.find(job.id)?.status, JobStatus.failed);
    });
  });
}
