import 'plugin_context.dart';

abstract class IPlugin {
  String get id => name.toLowerCase().replaceAll(' ', '_');
  String get name;
  String get version => "1.0.0";

  void register(PluginContext context);

  void unregister(PluginContext context) {}
}
