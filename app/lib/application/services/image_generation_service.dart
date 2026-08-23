import '../../core/providers/provider_registry.dart';
import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_engine.dart';
import '../../workflows/image/image_workflow.dart';
import '../../models/job.dart';

class ImageGenerationService {
  final WorkflowEngine engine;

  ImageGenerationService({
    required this.engine,
  });

  Future<Job> generateImage(
    String prompt,
  ) async {
    final provider =
        ProviderRegistry().get<ImageProvider>("comfyui");

    final workflow = ImageWorkflow(provider);

    final context = WorkflowContext();

    context.set("prompt", prompt);

    final result = await engine.runWithContext(
      workflow,
      context,
    );

    return result.get<Job>("image")!;
  }
}