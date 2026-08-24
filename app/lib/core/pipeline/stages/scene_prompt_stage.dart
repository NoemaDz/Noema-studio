import 'dart:convert';
import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../../workflows/scenes/scene_prompt_workflow.dart';
import '../../workflow/workflow_context.dart';
import '../../utils/json_extractor.dart';


/// Pipeline Stage: Scene Prompt Generation
/// Runs the ScenePromptWorkflow to build AI image prompts for each scene.
/// Uses JsonExtractor to safely parse LLM output even if it contains markdown.
class ScenePromptStage implements PipelineStage {
  @override
  int get priority => 40;

  final WorkflowEngine engine;

  ScenePromptStage({required this.engine});

  @override
  Future<void> run(NoemaProject project) async {
    final workflow = ScenePromptWorkflow(project.style);
    final context = WorkflowContext();
    context.set('project', project);

    await engine.runWithContext(workflow, context);

    if (context.contains('prompts')) {
      final rawResponse = context.get<String>('prompts')!;
      final cleanJson = JsonExtractor.extract(rawResponse);
      try {
        final promptsMap = jsonDecode(cleanJson) as Map<String, dynamic>;
        final promptsList = promptsMap['prompts'] as List;
        for (int i = 0; i < promptsList.length && i < project.story.scenes.length; i++) {
          final promptData = promptsList[i] as Map<String, dynamic>;
          final scene = project.story.scenes[i];
          scene.imagePrompt = promptData['imagePrompt'] as String?
              ?? promptData['prompt'] as String?
              ?? scene.description;
        }
      } catch (e) {
        // Non-fatal: fallback to scene description as prompt
        for (final scene in project.story.scenes) {
          scene.imagePrompt ??= scene.description;
        }
      }
    }
  }
}