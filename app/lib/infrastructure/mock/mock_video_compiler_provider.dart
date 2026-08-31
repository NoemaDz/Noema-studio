import '../../core/providers/video_compiler_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:uuid/uuid.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class MockVideoCompilerProvider extends VideoCompilerProvider {
  final Map<String, ExecutionResult> _results = {};
  @override
  String get id => "mock_ffmpeg";

  @override
  String get name => "Mock FFmpeg";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  @override
  Future<Job> execute(ExecutionRequest request) async {
    final jobId = request.jobId ?? const Uuid().v4();
    final outputPath =
        request.parameters['output_path'] as String? ?? "mock_output.mp4";
    final simulateFailure = request.parameters['simulate_failure'] == true;

    _results[jobId] = simulateFailure
        ? ExecutionResult.failure(JobError(code: 'err', message: 'err'))
        : ExecutionResult.success(textOutput: outputPath);

    return Job(
      id: jobId,
      providerId: id,
      type: "video_compile",
      status: JobStatus.running,
      metadata: {"outputPath": outputPath},
    );
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    return JobStatusUpdate(status: JobStatus.running, progress: 1.0);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    return _results[jobId] ??
        ExecutionResult.failure(
          JobError(code: 'not_found', message: 'Job not found'),
        );
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
