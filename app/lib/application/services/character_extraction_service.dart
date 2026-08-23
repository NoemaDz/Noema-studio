import 'dart:convert';

import '../../core/providers/provider_registry.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_engine.dart';
import '../../core/noema_project.dart';

import '../../workflows/characters/character_workflow.dart';

import '../../models/character_list.dart';




class CharacterExtractionService {
  final WorkflowEngine engine;

  CharacterExtractionService({
    required this.engine,
  });

  Future<void> extractCharacters(
  NoemaProject project,
) async {
  final provider =
      ProviderRegistry().get<LLMProvider>("ollama");

  final workflow = CharacterWorkflow(provider);

  final context = WorkflowContext();

  context.set(
    "story",
    jsonEncode(project.story.toJson()),
  );

  final result = await engine.runWithContext(
    workflow,
    context,
  );

  final characters = CharacterList.fromJson(
    jsonDecode(
      result.get<String>("characters")!,
    ),
  );

  project.characters
    ..clear()
    ..addAll(characters.characters);
}
}