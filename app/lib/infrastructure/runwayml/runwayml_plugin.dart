import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import '../../core/capabilities/capability.dart';
import '../../core/providers/video_provider.dart';
import '../../models/job.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/contracts/execution_result.dart';

class RunwayMLVideoProvider extends VideoProvider {
  @override
  String get id => 'runwayml_video';

  @override
  String get name => 'RunwayML Cloud Gen-3';

  @override
  bool get available => true; // Needs API Key check in the future

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  @override
  Future<Job> execute(ExecutionRequest request) async {
    throw UnimplementedError("RunwayML Cloud Video generation is coming soon.");
  }

  @override
  Future<ExecutionResult> getResult(String jobId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelJob(String jobId) async {}

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) async {
    return JobStatusUpdate(status: job.status);
  }
}

class RunwayMLPlugin extends IPlugin {
  @override
  String get id => 'noema_runwayml';

  @override
  String get name => 'RunwayML Cloud Plugin';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(RunwayMLVideoProvider());
  }

  @override
  void unregister(PluginContext context) {
    // Cleanup resources if any
  }
}
