import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../builder/prompt_template_service.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../core/providers/llm_provider.dart';

class ExtractCharactersStep extends WorkflowStep<List<Map<String, dynamic>>> {
  final LLMProvider provider;
  final PromptTemplateService promptService = PromptTemplateService();

  ExtractCharactersStep(this.provider);

  @override
  String get id => "extract_characters";

  @override
  String get name => "Extract Characters";

  @override
  Future<List<Map<String, dynamic>>> execute(WorkflowContext context) async {
    final storyText = context.get<String>("story")!;

    final prompt = await promptService.load("characters", {"story": storyText});

    final request = ExecutionRequest(
      capability: CapabilityType.llm,
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
    final response = result.textOutput ?? "";

    try {
      final startIndex = response.indexOf('[');
      final endIndex = response.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final jsonArrayStr = response.substring(startIndex, endIndex + 1);
        final List<dynamic> parsed = jsonDecode(jsonArrayStr);
        return parsed.cast<Map<String, dynamic>>();
      } else {
        throw FormatException("Could not find JSON array in response.");
      }
    } catch (e) {
      debugPrint("Error parsing characters JSON: $e\nResponse was:\n$response");
      return [];
    }
  }
}
