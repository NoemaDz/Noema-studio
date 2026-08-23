import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/style.dart';
import '../../builder/scene_prompt_builder.dart';
import '../../core/noema_project.dart';

class BuildScenePromptsStep extends WorkflowStep<void> {
  final Style style;

  final ScenePromptBuilder builder =
      ScenePromptBuilder();

  BuildScenePromptsStep(this.style);

  @override
  String get id => "scene_prompts";

  @override
  String get name => "Build Scene Prompts";

  @override
  Future<void> execute(
    WorkflowContext context,
  ) async {
    final project =
        context.get<NoemaProject>("project")!;

    for (final scene in project.story.scenes) {
      scene.imagePrompt = builder.build(
        scene: scene.description,
        characters: project.characters,
        style: style,
      );
    }
  }
}