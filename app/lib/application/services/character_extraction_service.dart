import 'dart:convert';

import '../../core/providers/provider_registry.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_engine.dart';
import '../../core/noema_project.dart';

import '../../workflows/characters/character_workflow.dart';

import '../../models/character.dart';

class CharacterExtractionService {
  final WorkflowEngine engine;

  CharacterExtractionService({required this.engine});

  Future<void> extractCharacters(NoemaProject project) async {
    final provider = ProviderRegistry().get<LLMProvider>("ollama");

    final workflow = CharacterWorkflow(provider);

    final context = WorkflowContext();

    context.set("story", jsonEncode(project.story.toJson()));

    final result = await engine.runWithContext(workflow, context);

    final rawCharacters = result.get<List<Map<String, dynamic>>>(
      "extract_characters",
    )!;

    final characters = rawCharacters.map((e) => Character.fromJson(e)).toList();

    project.characters
      ..clear()
      ..addAll(characters);
  }
}
