import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../builder/prompt_template_service.dart';

class ExtractCharactersStep extends WorkflowStep<String> {
  final LLMProvider provider;

  final PromptTemplateService promptService = PromptTemplateService();

  ExtractCharactersStep(this.provider);

  @override
  String get id => "characters";

  @override
  String get name => "Extract Characters";

  @override
  Future<String> execute(WorkflowContext context) async {
    final story = context.get<String>("story")!;

    final prompt = await promptService.load("characters", {"story": story});

    return await provider.generate(prompt);
  }
}
