import '../providers/provider.dart';
import '../providers/provider_registry.dart';
import 'capability.dart';

class HardwareContext {
  final int totalVRAMGB;

  HardwareContext({required this.totalVRAMGB});
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

    // Iterate through all available providers supporting the capability
    // (For now, we just hardcode the fallback logic to find a cloud provider)

    // Naive fallback mechanism: Find the first provider that ends with '_video' (if it's video)
    // and meets the requirements.
    for (final provider in registry.all) {
      if (capability.type == CapabilityType.videoGeneration &&
          provider.id.endsWith('_video')) {
        if (_meetsHardwareRequirements(provider, capability)) {
          return provider;
        }
      }
    }

    return null;
  }

  bool _meetsHardwareRequirements(Provider provider, Capability capability) {
    if (!provider.available) return false;

    // Currently, we assume cloud providers (e.g. runwayml, sora) require 0 VRAM
    // Local providers (e.g. comfyui) require > 0 VRAM
    // Since we don't have a formal way to query a provider's required VRAM yet,
    // we'll use a heuristic: if the provider name contains "Cloud", it requires 0 VRAM.
    // Otherwise, we enforce the capability's required VRAM.

    final requiresGPU =
        !provider.id.startsWith('runway') &&
        !provider.id.startsWith('sora') &&
        !provider.id.startsWith('mock');

    if (requiresGPU) {
      return hardware.totalVRAMGB >= capability.requiredVRAMGB;
    }

    return true; // Cloud/Mock always pass hardware constraints
  }
}
