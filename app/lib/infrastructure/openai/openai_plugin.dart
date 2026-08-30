import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/capabilities/capability.dart';
import 'openai_driver.dart';

import 'package:uuid/uuid.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';
import '../../models/job.dart';

class OpenAIProvider extends LLMProvider {
  final OpenAIDriver _driver = OpenAIDriver();
  final Map<String, ExecutionResult> _results = {};

  @override
  String get id => 'openai';

  @override
  String get name => 'Generic OpenAI Compatible API';

  @override
  bool get available => true; // handled at plugin level if needed

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.textGeneration};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final jobId = request.jobId ?? const Uuid().v4();
    final job = Job(
      id: jobId,
      providerId: id,
      type: request.capability.name,
      status: JobStatus.running,
    );

    _runAsync(job, request.input);
    return job;
  }

  Future<void> _runAsync(Job job, String prompt) async {
    try {
      final result = await _driver.generateStory(prompt);
      _results[job.id] = ExecutionResult.success(textOutput: result);
      job.transitionTo(JobStatus.completed);
    } catch (e) {
      _results[job.id] = ExecutionResult.failure(
        JobError(code: 'error', message: e.toString()),
      );
      job.error = JobError(code: 'error', message: e.toString());
      job.transitionTo(JobStatus.failed);
    }
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    return _results[jobId] ??
        ExecutionResult.failure(
          JobError(code: 'not_found', message: 'Result not found'),
        );
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}

class OpenAIPlugin extends IPlugin {
  @override
  String get id => 'openai_api';

  @override
  String get name => 'OpenAI API Plugin';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(OpenAIProvider());
  }
}
