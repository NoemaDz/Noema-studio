import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'openai_image_provider.dart';

class OpenAIImagePlugin implements IPlugin {
  @override
  String get name => 'OpenAI Image Generator';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(OpenAIImageProvider(context));
  }
}
