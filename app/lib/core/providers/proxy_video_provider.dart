import 'video_provider.dart';
import '../../models/job.dart';
import '../plugins/plugin_context.dart';
import '../../models/asset.dart';

class ProxyVideoProvider extends VideoProvider {
  final PluginContext context;

  ProxyVideoProvider(this.context);

  @override
  String get id => "proxy_video";

  @override
  String get name => "Proxy Video Provider";

  @override
  bool get available => true;

  VideoProvider get _activeProvider {
    final providerId = context
        .appSettings
        .activeImageProvider; // We reuse the active provider setting or add activeVideoProvider
    // For now, if activeImageProvider is "comfyui", we use "comfyui_video"
    final targetId = "${providerId}_video";
    final provider = context.providers.get<VideoProvider>(targetId);
    return provider;
  }

  @override
  Future<Job> submitJob(
    String prompt,
    String imagePath, {
    Map<String, dynamic>? options,
  }) {
    return _activeProvider.submitJob(prompt, imagePath, options: options);
  }

  @override
  Future<JobStatus> getJobStatus(String jobId) {
    return _activeProvider.getJobStatus(jobId);
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
