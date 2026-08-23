import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'mock_tts_provider.dart';
import 'mock_video_compiler_provider.dart';

class MockMediaPlugin implements IPlugin {
  @override
  String get name => 'Mock Media Providers';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(MockTTSProvider());
    context.providers.register(MockVideoCompilerProvider());
  }
}
