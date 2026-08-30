import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/core/capabilities/capability_resolver.dart';
import 'package:noema_studio/core/providers/provider.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';

class MockProvider extends Provider {
  @override
  final String id;
  @override
  final String name;
  @override
  final bool available;
  @override
  final Set<CapabilityType> capabilities;
  @override
  final HardwareRequirements hardwareRequirements;

  MockProvider({
    required this.id,
    required this.name,
    this.available = true,
    required this.capabilities,
    required this.hardwareRequirements,
  });
}

void main() {
  group('CapabilityResolver Routing', () {
    late ProviderRegistry registry;

    setUp(() {
      registry = ProviderRegistry();
      // Add local provider (needs 8GB VRAM)
      registry.register(
        MockProvider(
          id: 'local_video',
          name: 'Local Video',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: true,
            minimumVRAMGB: 8,
          ),
        ),
      );

      // Add cloud provider (needs 0 VRAM)
      registry.register(
        MockProvider(
          id: 'cloud_video',
          name: 'Cloud Video',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: false,
            minimumVRAMGB: 0,
          ),
        ),
      );

      // Add another unrelated provider
      registry.register(
        MockProvider(
          id: 'tts_provider',
          name: 'TTS Provider',
          capabilities: {CapabilityType.tts},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: false,
            minimumVRAMGB: 0,
          ),
        ),
      );
    });

    test('Routes to cloud when VRAM is insufficient (6GB)', () {
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 6,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'local_video',
      );

      expect(provider, isNotNull);
      expect(provider!.id, equals('cloud_video'));
    });

    test('Routes to local when VRAM is sufficient (12GB)', () {
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 12,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'local_video',
      );

      expect(provider, isNotNull);
      expect(provider!.id, equals('local_video')); // Preferred and capable
    });

    test('Fails when no provider supports capability', () {
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 12,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      // Create a dummy capability that no provider registered supports
      final dummyCapability = _DummyCapability();
      final provider = resolver.resolve(dummyCapability);

      expect(provider, isNull);
    });

    test('Ignores unavailable preferred provider', () {
      registry.register(
        MockProvider(
          id: 'unavailable_video',
          name: 'Unavailable Video',
          available: false,
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: false,
            minimumVRAMGB: 0,
          ),
        ),
      );

      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 12,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'unavailable_video',
      );

      // Should fall back to the next available one (local_video or cloud_video)
      expect(provider, isNotNull);
      expect(provider!.id, isNot('unavailable_video'));
      expect(
        provider.id,
        equals('local_video'),
      ); // first in registry.all that matches
    });
  });
}

class _DummyCapability extends Capability {
  @override
  CapabilityType get type => CapabilityType.lipSync;

  @override
  bool get requiresGPU => false;

  @override
  int get requiredVRAMGB => 0;
}
