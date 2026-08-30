import '../../core/providers/llm_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../builder/prompt_template_service.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';

class GenerateStoryStep extends WorkflowStep<String> {
  final LLMProvider provider;

  final PromptTemplateService promptService = PromptTemplateService();

  GenerateStoryStep(this.provider);

  @override
  String get id => "story";

  @override
  String get name => "Generate Story";

  @override
  Future<String> execute(WorkflowContext context) async {
    final idea = context.get<String>("idea")!;

    final prompt = await promptService.load("story", {"idea": idea});

    final request = ExecutionRequest(
      capability: CapabilityType.textGeneration,
      input: prompt,
    );
    final job = await provider.execute(request);

    while (job.status == JobStatus.pending || job.status == JobStatus.running) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (job.status == JobStatus.failed) {
      throw Exception(job.error?.message ?? 'LLM Generation failed');
    }

    final result = await provider.getResult(job.id);
    return result.textOutput ?? "";
  }
}
