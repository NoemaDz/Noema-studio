import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'google_gemini_image_provider.dart';
import 'google_gemini_video_provider.dart';

class GeminiPlugin extends IPlugin {
  @override
  String get id => "gemini";

  @override
  String get name => "Google Gemini";

  @override
  String get version => "1.0.0";

  @override
  void register(PluginContext context) {
    context.providers.register(GoogleGeminiImageProvider(context));
    context.providers.register(GoogleGeminiVideoProvider(context));
  }
}
