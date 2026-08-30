import '../../core/providers/video_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'comfyui_driver.dart';
import '../../models/asset.dart';

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
  Future<Job> submitJob(
    String prompt,
    String imagePath, {
    Map<String, dynamic>? options,
  }) {
    final opts = options != null
        ? Map<String, dynamic>.from(options)
        : <String, dynamic>{};
    opts["is_video"] = true;
    opts["source_image_path"] = imagePath;
    return driver.submitJob(prompt, options: opts);
  }

  @override
  Future<void> updateJobStatus(Job job) {
    return driver.updateJobStatus(job);
  }

  @override
  Future<Asset?> downloadAsset(String jobId) {
    return driver.downloadAsset(jobId);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return driver.cancelJob(jobId);
  }
}
