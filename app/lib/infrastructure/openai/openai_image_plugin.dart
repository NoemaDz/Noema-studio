import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'openai_image_provider.dart';

class OpenAIImagePlugin extends IPlugin {
  @override
  String get id => 'openai_image_plugin';

  @override
  String get name => 'OpenAI Image Generator';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(OpenAIImageProvider(context));
  }
}
