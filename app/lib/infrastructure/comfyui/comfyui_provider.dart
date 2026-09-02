import '../../core/providers/image_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'comfyui_driver.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';
import '../../core/plugins/plugin_context.dart';

class ComfyUIProvider extends ImageProvider {
  final PluginContext context;
  late final ComfyUIDriver driver;

  ComfyUIProvider(this.context, {ComfyUIDriver? driver}) {
    this.driver = driver ?? ComfyUIDriver(context);
  }

  @override
  String get id => "comfyui";

  @override
  String get name => "ComfyUI";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: true, minimumVRAMGB: 6);

  @override
  Future<Job> execute(ExecutionRequest request) {
    return driver.submitJob(request.input, options: request.parameters);
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
