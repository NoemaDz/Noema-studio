import '../../core/plugins/plugin_context.dart';
import '../../core/providers/image_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../models/asset.dart';

class ProxyImageProvider extends ImageProvider {
  final PluginContext context;

  ProxyImageProvider(this.context);

  @override
  String get id => "proxy_image";

  @override
  String get name => "Proxy Image Provider";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();

  ImageProvider get _activeProvider {
    final activeId = context.appSettings.activeImageProvider;
    return context.providers.all.whereType<ImageProvider>().firstWhere(
      (p) => p.id == activeId && p.id != "proxy_image",
      orElse: () => context.providers.all.whereType<ImageProvider>().firstWhere(
        (p) => p.id != "proxy_image",
      ),
    );
  }

  @override
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) {
    return _activeProvider.submitJob(prompt, options: options);
  }

  @override
  Future<void> updateJobStatus(Job job) {
    return _activeProvider.updateJobStatus(job);
  }

  @override
  Future<Asset?> downloadAsset(String jobId) {
    return _activeProvider.downloadAsset(jobId);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return _activeProvider.cancelJob(jobId);
  }
}
