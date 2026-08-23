import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';

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

    final options = context.get<Map<String, dynamic>>("options");
    final job = await provider.submitJob(prompt, options: options);

   job.metadata["prompt"] = prompt;

      return job;
  }
}