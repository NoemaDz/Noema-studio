import 'dart:async';
import '../../agent/llm_client.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';

class ProviderLlmClient implements LlmClient {
  final LLMProvider provider;

  ProviderLlmClient(this.provider);

  @override
  Future<String> generateText(String prompt) async {
    final request = ExecutionRequest(
      capability: CapabilityType.llm,
      input: prompt,
    );

    final job = await provider.execute(request);

    // Wait for the provider to complete the job
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
