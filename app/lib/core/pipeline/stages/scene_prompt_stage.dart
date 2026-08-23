import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../../workflows/scenes/scene_prompt_workflow.dart';
import '../../workflow/workflow_context.dart';

class ScenePromptStage implements PipelineStage {
  @override
  int get priority => 40;

  final WorkflowEngine engine;

ScenePromptStage({
  required this.engine,
   });



  @override
Future<void> run(
  NoemaProject project,
) async {
  final workflow = ScenePromptWorkflow(
    project.style,
  );

  final context = WorkflowContext();

  context.set(
    "project",
    project,
  );

  await engine.runWithContext(
    workflow,
    context,
  );
}
}