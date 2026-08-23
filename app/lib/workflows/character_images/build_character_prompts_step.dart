import '../../core/noema_project.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';

import '../../builder/character_prompt_builder.dart';

class BuildCharacterPromptsStep
    extends WorkflowStep<void> {
  final CharacterPromptBuilder builder =
      CharacterPromptBuilder();

  @override
  String get id => "character_prompts";

  @override
  String get name => "Build Character Prompts";

  @override
  Future<void> execute(
    WorkflowContext context,
  ) async {
    final project =
        context.get<NoemaProject>("project")!;

    for (final character in project.characters) {
      character.prompt = builder.build(
        character: character,
        style: project.style,
      );
    }
  }
}