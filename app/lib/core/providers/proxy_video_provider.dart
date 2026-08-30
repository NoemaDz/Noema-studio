import 'video_provider.dart';
import '../../models/job.dart';
import '../plugins/plugin_context.dart';
import '../../models/asset.dart';
import '../capabilities/capability.dart';
import '../contracts/execution_request.dart';
import '../contracts/execution_result.dart';

class ProxyVideoProvider extends VideoProvider {
  final PluginContext context;

  ProxyVideoProvider(this.context);

  @override
  String get id => "proxy_video";

  @override
  String get name => "Proxy Video Provider";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  VideoProvider get _activeProvider {
    final preferredId = "${context.appSettings.activeImageProvider}_video";
    final capability = VideoGenerationCapability(
      requiresGPU: true,
      requiredVRAMGB: 8,
    );

    final provider = context.capabilityResolver.resolve(
      capability,
      preferredProviderId: preferredId,
    );

    if (provider == null || provider is! VideoProvider) {
      throw Exception(
        "No suitable video provider found for the current hardware capabilities.",
      );
    }

    return provider;
  }

  @override
  Future<Job> execute(ExecutionRequest request) {
    return _activeProvider.execute(request);
  }

  @override
  Future<JobStatusUpdate> updateJobStatus(Job job) {
    return _activeProvider.updateJobStatus(job);
  }

  @override
  Future<ExecutionResult> getResult(String jobId) {
    return _activeProvider.getResult(jobId);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return _activeProvider.cancelJob(jobId);
  }
}
