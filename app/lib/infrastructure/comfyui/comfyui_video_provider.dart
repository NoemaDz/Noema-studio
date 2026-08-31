import '../../core/providers/video_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'comfyui_driver.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';
import '../../core/plugins/plugin_context.dart';

class ComfyUIVideoProvider extends VideoProvider {
  final PluginContext context;
  late final ComfyUIDriver driver;

  ComfyUIVideoProvider(this.context) {
    driver = ComfyUIDriver(context);
  }

  @override
  String get id => "comfyui_video";

  @override
  String get name => "ComfyUI Video";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: true, minimumVRAMGB: 8);

  @override
  Future<Job> execute(ExecutionRequest request) {
    final opts = request.parameters.isNotEmpty
        ? Map<String, dynamic>.from(request.parameters)
        : <String, dynamic>{};
    opts["is_video"] = true;
    return driver.submitJob(request.input, options: opts);
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) {
    return driver.updateJobStatus(job);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    try {
      final artifact = await driver.downloadArtifact(jobId);
      if (artifact != null) {
        return ExecutionResult.success(artifact: artifact);
      } else {
        return ExecutionResult.failure(
          JobError(code: 'not_found', message: 'Artifact not found'),
        );
      }
    } catch (e) {
      return ExecutionResult.failure(
        JobError(code: 'download_failed', message: e.toString()),
      );
    }
  }

  @override
  Future<void> cancelJob(String jobId) {
    return driver.cancelJob(jobId);
  }
}
