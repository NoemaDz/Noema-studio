import 'plugin_context.dart';

abstract class IPlugin {
  String get id;
  String get name;
  String get version => "1.0.0";

  void register(PluginContext context);

  void unregister(PluginContext context) {}
}
