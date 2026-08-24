import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow.dart';
import 'extract_characters_step.dart';

class CharacterWorkflow extends Workflow {
  CharacterWorkflow(LLMProvider provider)
    : super(
        id: "character_workflow",
        name: "Character Workflow",
        steps: [ExtractCharactersStep(provider)],
      );
}
