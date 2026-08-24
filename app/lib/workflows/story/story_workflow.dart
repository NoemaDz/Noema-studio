import '../../core/workflow/workflow.dart';
import '../../core/providers/llm_provider.dart';
import 'generate_story_step.dart';

class StoryWorkflow extends Workflow {
  StoryWorkflow(LLMProvider provider)
    : super(
        id: "story_workflow",
        name: "Story Workflow",
        steps: [GenerateStoryStep(provider)],
      );
}
