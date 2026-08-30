import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'ffmpeg_video_compiler.dart';

class FFmpegPlugin extends IPlugin {
  @override
  String get id => 'ffmpeg_plugin';

  @override
  String get name => 'FFmpeg Video Compiler';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(
      FFmpegVideoCompilerProvider(context.appSettings),
    );
  }
}
