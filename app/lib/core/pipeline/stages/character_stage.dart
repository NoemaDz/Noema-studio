import 'dart:convert';

import '../../providers/llm_provider.dart';
import '../../workflow/workflow_context.dart';
import '../../workflow/workflow_engine.dart';

import '../../../models/character_list.dart';
import '../../../workflows/characters/character_workflow.dart';
import '../../noema_project.dart';
import '../contracts/pipeline_stage.dart';



class CharacterStage implements PipelineStage {
  @override
  int get priority => 20;

  final WorkflowEngine engine;
  final LLMProvider provider;

   CharacterStage({
  required this.engine,
  required this.provider,
  });

  @override
  Future<void> run(
  NoemaProject project,
)
   async {
    

    final workflow =
        CharacterWorkflow(provider);

    final context = WorkflowContext();

    context.set(
      "story",
      jsonEncode(project.story.toJson()),
    );
    
    final result =
        await engine.runWithContext(
      workflow,
      context,
    );

    final rawResponse = result.get<String>("characters")!;
    final cleanJson = _extractJson(rawResponse);

    try {
      final characters = CharacterList.fromJson(
        jsonDecode(cleanJson),
      );

      project.characters
        ..clear()
        ..addAll(characters.characters);
    } catch (e) {
      print("Warning: Failed to parse characters: \$e");
    }
  }

  String _extractJson(String response) {
    final startIndex = response.indexOf('{');
    final endIndex = response.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
      return response.substring(startIndex, endIndex + 1);
    }
    return response.trim();
  }
}