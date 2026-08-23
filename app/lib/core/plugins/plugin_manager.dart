import 'plugin_interface.dart';
import 'plugin_context.dart';

class PluginManager {
  final PluginContext context;
  final List<IPlugin> _plugins = [];

  PluginManager({required this.context});

  void loadPlugins(List<IPlugin> plugins) {
    for (final plugin in plugins) {
      _plugins.add(plugin);
      plugin.register(context);
    }
  }

  List<IPlugin> get plugins => List.unmodifiable(_plugins);
}
