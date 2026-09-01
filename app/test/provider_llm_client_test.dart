import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/application/services/provider_llm_client.dart';
import 'package:noema_studio/core/providers/llm_provider.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/contracts/execution_result.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/core/capabilities/capability.dart';

class MockLLMProvider extends LLMProvider {
  final JobStatus initialStatus;
  final String? resultText;
  final bool shouldFail;

  MockLLMProvider({
    this.initialStatus = JobStatus.running,
    this.resultText,
    this.shouldFail = false,
  });

  @override
  String get id => 'mock_llm';

  @override
  String get name => 'Mock LLM';

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.llm};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  late Job _activeJob;

  @override
  Future<Job> execute(ExecutionRequest request) async {
    _activeJob = Job(
      id: 'mock_job_1',
      providerId: id,
      type: request.capability.name,
      status: initialStatus,
    );

    // Simulate async job completion
    Future.delayed(const Duration(milliseconds: 300), () {
      if (shouldFail) {
        _activeJob.error = JobError(
          code: 'error',
          message: 'Simulated failure',
        );
        _activeJob.forceStatus(JobStatus.failed);
      } else {
        _activeJob.forceStatus(JobStatus.completed);
      }
    });

    return _activeJob;
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    if (shouldFail) {
      return ExecutionResult.failure(
        JobError(code: 'error', message: 'Simulated failure'),
      );
    }
    return ExecutionResult.success(textOutput: resultText);
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}

void main() {
  group('ProviderLlmClient', () {
    test('successfully generates text and waits for job completion', () async {
      final mockProvider = MockLLMProvider(resultText: '[{"id": "test"}]');
      final client = ProviderLlmClient(mockProvider);

      final startTime = DateTime.now();
      final result = await client.generateText('test prompt');
      final endTime = DateTime.now();

      expect(result, '[{"id": "test"}]');
      expect(
        endTime.difference(startTime).inMilliseconds,
        greaterThanOrEqualTo(300),
      );
    });

    test('throws exception on job failure', () async {
      final mockProvider = MockLLMProvider(shouldFail: true);
      final client = ProviderLlmClient(mockProvider);

      expect(
        () async => await client.generateText('test prompt'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Simulated failure'),
          ),
        ),
      );
    });
  });
}
