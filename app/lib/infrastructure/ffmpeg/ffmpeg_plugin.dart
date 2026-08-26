import '../../core/plugins/plugin_interface.dart';
import '../../core/plugins/plugin_context.dart';
import 'ffmpeg_video_compiler.dart';

class FFmpegPlugin implements IPlugin {
  @override
  String get name => 'FFmpeg Video Compiler';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(FFmpegVideoCompilerProvider(context.appSettings));
  }
}
