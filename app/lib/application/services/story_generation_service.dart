import '../../core/providers/provider_registry.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_engine.dart';
import '../../workflows/story/story_workflow.dart';

class StoryGenerationService {
  final WorkflowEngine engine;

  StoryGenerationService({
    required this.engine,
  });



  Future<String> generateStory(
  String idea,
 ) async {
  final provider =
      ProviderRegistry().get<LLMProvider>("ollama");

  final workflow = StoryWorkflow(provider);

  final context = WorkflowContext();

  context.set("idea", idea);

  final result = await engine.runWithContext(
    workflow,
    context,
  );

  return result.get<String>("story")!;
 }

}