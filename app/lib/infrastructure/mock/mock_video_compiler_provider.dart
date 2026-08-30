import '../../core/providers/video_compiler_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:uuid/uuid.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class MockVideoCompilerProvider extends VideoCompilerProvider {
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
    return Job(
      id: jobId,
      providerId: id,
      type: "video_compile",
      status: JobStatus.completed,
      result: outputPath,
      metadata: {"outputPath": outputPath},
    );
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    return ExecutionResult.success(textOutput: "mock_output.mp4");
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
