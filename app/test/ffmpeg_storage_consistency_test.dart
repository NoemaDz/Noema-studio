import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/models/job.dart';

import 'package:noema_studio/infrastructure/mock/mock_video_compiler_provider.dart';
import 'package:noema_studio/models/artifact.dart';
import 'package:noema_studio/models/artifact_type.dart';

void main() {
  group('FFmpeg Storage Consistency & Job State', () {
    test(
      'Job completion yields execution result with permanent path',
      () async {
        final provider = MockVideoCompilerProvider();

        final request = ExecutionRequest(
          capability: CapabilityType.videoGeneration,
          input: 'Test compile',
          parameters: {'output_path': 'final_output.mp4'},
        );

        final job = await provider.execute(request);

        // Since it's a mock, it's completed immediately
        expect(job.status, JobStatus.completed);

        // Verify that the authoritative Job state is retrieved
        final result = await provider.getResult(job.id);
        expect(result.isSuccess, true);
        expect(result.textOutput, isNotNull);
        expect(result.textOutput, endsWith('.mp4'));

        // Validate the artifact creation simulation
        final artifact = Artifact(
          id: job.id,
          path: result.textOutput!,
          type: ArtifactType.video,
        );

        expect(artifact.path, isNotEmpty);
      },
    );
  });
}
