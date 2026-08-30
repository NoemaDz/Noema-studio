import '../../core/providers/llm_provider.dart';
import '../../core/capabilities/capability.dart';
import 'ollama_driver.dart';

import 'package:uuid/uuid.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';
import '../../models/job.dart';

class OllamaProvider extends LLMProvider {
  final OllamaDriver service = OllamaDriver();
  final Map<String, ExecutionResult> _results = {};

  @override
  String get id => "ollama";

  @override
  String get name => "Ollama";

  @override
  bool get available => true;

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

    // Run asynchronously without blocking the return of the Job
    _runAsync(job, request.input);
    return job;
  }

  Future<void> _runAsync(Job job, String prompt) async {
    try {
      final result = await service.generateStory(prompt);
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
  Future<void> cancelJob(String jobId) async {
    // OllamaDriver currently might not support cancellation natively.
  }
}
