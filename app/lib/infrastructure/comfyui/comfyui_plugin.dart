import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'comfyui_provider.dart';
import 'comfyui_video_provider.dart';

class ComfyUIPlugin implements IPlugin {
  @override
  String get name => 'ComfyUI Image Generator';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(ComfyUIProvider(context));
    context.providers.register(ComfyUIVideoProvider(context));
  }
}
