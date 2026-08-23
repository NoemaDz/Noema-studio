import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../builder/prompt_template_service.dart';

class GenerateStoryStep extends WorkflowStep<String> {
  final LLMProvider provider;

  final PromptTemplateService promptService =
      PromptTemplateService();

  GenerateStoryStep(this.provider);

  @override
  String get id => "story";

  @override
  String get name => "Generate Story";

  @override
  Future<String> execute(
    WorkflowContext context,
  ) async {
    final idea = context.get<String>("idea")!;

    final prompt = await promptService.load(
      "story",
      {
        "idea": idea,
      },
    );

    return await provider.generate(prompt);
  }
}