import '../providers/provider.dart';
import '../providers/provider_registry.dart';
import 'capability.dart';

class HardwareContext {
  final bool hasGPU;
  final int totalVRAMGB;
  final String os;
  final bool hasCUDA;

  const HardwareContext({
    required this.hasGPU,
    required this.totalVRAMGB,
    required this.os,
    required this.hasCUDA,
  });
}

class CapabilityResolver {
  final ProviderRegistry registry;
  final HardwareContext hardware;

  CapabilityResolver(this.registry, this.hardware);

  /// Resolves the best provider for the given capability.
  /// If a [preferredProviderId] is given, it is checked first.
  /// If it fails hardware constraints, it falls back to alternative providers.
  Provider? resolve(Capability capability, {String? preferredProviderId}) {
    if (preferredProviderId != null) {
      final preferred = registry.getOrNull<Provider>(preferredProviderId);
      if (preferred != null &&
          _meetsHardwareRequirements(preferred, capability)) {
        return preferred;
      }
      // If preferred provider doesn't meet requirements, fallback
      print(
        "CapabilityResolver: Preferred provider '$preferredProviderId' does not meet hardware requirements or is unavailable. Falling back...",
      );
    }

    // 1. Iterate through all available providers supporting the capability
    for (final provider in registry.all) {
      if (provider.capabilities.contains(capability.type)) {
        if (_meetsHardwareRequirements(provider, capability)) {
          return provider;
        }
      }
    }

    return null;
  }

  bool _meetsHardwareRequirements(Provider provider, Capability capability) {
    if (!provider.available) return false;

    final req = provider.hardwareRequirements;

    // Strict hardware checks based on declared requirements
    if (req.requiresGPU && !hardware.hasGPU) return false;
    if (hardware.totalVRAMGB < req.minimumVRAMGB) return false;
    if (req.requiresCUDA && !hardware.hasCUDA) return false;
    if (req.supportedOS != null && req.supportedOS != hardware.os) return false;

    return true;
  }
}
