import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';
import '../../core/workflow/workflow_context.dart';

class GenerateImageStep extends WorkflowStep<Job> {
  final ImageProvider provider;

  GenerateImageStep(this.provider);

  @override
  String get id => "image";

  @override
  String get name => "Generate Image";

  @override
  Future<Job> execute(WorkflowContext context) async {
    final prompt = context.get<String>("prompt");

    if (prompt == null) {
      throw Exception("Missing image prompt");
    }

    final request = ExecutionRequest(
      capability: CapabilityType.imageGeneration,
      input: prompt,
    );
    final job = await provider.execute(request);

    job.metadata["prompt"] = prompt;

    return job;
  }
}
