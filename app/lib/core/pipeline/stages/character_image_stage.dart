import '../../noema_project.dart';
import './../contracts/pipeline_stage.dart';
import '../../providers/image_provider.dart';
import '../../workflow/workflow_context.dart';
import '../../workflow/workflow_engine.dart';

import '../../../workflows/character_images/character_image_workflow.dart';

class CharacterImageStage implements PipelineStage {
  @override
  int get priority => 30;

  final WorkflowEngine engine;

  final ImageProvider provider;

  CharacterImageStage({required this.engine, required this.provider});

  @override
  Future<void> run(NoemaProject project) async {
    final workflow = CharacterImageWorkflow(provider);

    final context = WorkflowContext();

    context.set("project", project);

    await engine.runWithContext(workflow, context);
  }
}
