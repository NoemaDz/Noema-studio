import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow.dart';

import 'build_character_prompts_step.dart';
import 'generate_character_images_step.dart';

class CharacterImageWorkflow extends Workflow {
  CharacterImageWorkflow(ImageProvider provider)
    : super(
        id: "character_image_workflow",
        name: "Character Image Workflow",
        steps: [
          BuildCharacterPromptsStep(),
          GenerateCharacterImagesStep(provider),
        ],
      );
}
