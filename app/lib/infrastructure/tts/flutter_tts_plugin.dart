import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'flutter_tts_provider.dart';

class FlutterTTSPlugin implements IPlugin {
  @override
  String get name => 'Flutter TTS';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(FlutterTTSProvider());
  }
}
