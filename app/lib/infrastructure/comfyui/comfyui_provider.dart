import '../../core/providers/image_provider.dart';
import '../../models/job.dart';
import 'comfyui_driver.dart';
import '../../models/asset.dart';

import '../../core/plugins/plugin_context.dart';

class ComfyUIProvider extends ImageProvider {
  final PluginContext context;
  late final ComfyUIDriver driver;

  ComfyUIProvider(this.context) {
    driver = ComfyUIDriver(context);
  }

  @override
  String get id => "comfyui";

  @override
  String get name => "ComfyUI";

  @override
  bool get available => true;

  @override
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options}) {
    return driver.submitJob(prompt, options: options);
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
