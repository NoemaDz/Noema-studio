import '../../core/providers/video_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';

class GenerateVideoStep extends WorkflowStep<Job> {
  final VideoProvider provider;

  GenerateVideoStep(this.provider);

  @override
  String get id => "video";

  @override
  String get name => "Generate Video";

  @override
  Future<Job> execute(WorkflowContext context) async {
    final prompt = context.get<String>("prompt");
    final imagePath = context.get<String>("imagePath");

    if (prompt == null) {
      throw Exception("Missing video prompt");
    }

    if (imagePath == null) {
      throw Exception("Missing source image for video");
    }

    final request = ExecutionRequest(
      capability: CapabilityType.videoGeneration,
      input: prompt,
      parameters: {'imagePath': imagePath},
    );
    final job = await provider.execute(request);

    job.metadata["prompt"] = prompt;
    job.metadata["imagePath"] = imagePath;

    return job;
  }
}
