import 'provider.dart';

class ProviderRegistry {
  static final ProviderRegistry _instance = ProviderRegistry._internal();

  factory ProviderRegistry() => _instance;

  ProviderRegistry._internal();

  final Map<String, Provider> _providers = {};

  void register(Provider provider) {
    _providers[provider.id] = provider;
  }

  T get<T extends Provider>(String id) {
    final provider = _providers[id];

    if (provider == null) {
      throw Exception("Provider '$id' not found.");
    }

    return provider as T;
  }

  T? getOrNull<T extends Provider>(String id) {
    final provider = _providers[id];
    if (provider == null) return null;
    return provider as T;
  }

  T getDefault<T extends Provider>() {
    for (final provider in _providers.values) {
      if (provider is T) {
        return provider;
      }
    }
    throw Exception("No default Provider found for type '$T'.");
  }

  bool has(String id) {
    return _providers.containsKey(id);
  }

  List<Provider> get all => _providers.values.toList();
}
