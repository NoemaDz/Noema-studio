import '../../core/workflow/workflow.dart';
import '../../models/style.dart';

import 'build_scene_prompts_step.dart';

class ScenePromptWorkflow extends Workflow {
  ScenePromptWorkflow(
    Style style,
  ) : super(
          id: "scene_prompt_workflow",
          name: "Scene Prompt Workflow",
          steps: [
            BuildScenePromptsStep(style),
          ],
        );
}