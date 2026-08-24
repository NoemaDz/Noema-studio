import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../../workflows/scenes/scene_prompt_workflow.dart';
import '../../workflow/workflow_context.dart';
import '../../utils/json_extractor.dart';
import 'dart:convert';

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

  if (context.contains("prompts")) {
    final rawResponse = context.get<String>("prompts")!;
    final cleanJson = JsonExtractor.extract(rawResponse);
    try {
      final promptsMap = jsonDecode(cleanJson) as Map<String, dynamic>;
      final parsedList = promptsMap["prompts"] as List;
      // ... assume ScenePromptStage continues processing parsedList here
    } catch (e) {
      print("Failed to parse scene prompts: $e");
    }
  }
}
}