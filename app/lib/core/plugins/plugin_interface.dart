import 'plugin_context.dart';

abstract class IPlugin {
  String get name;
  String get version => "1.0.0";

  void register(PluginContext context);
}
