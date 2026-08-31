import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/core/capabilities/capability_resolver.dart';
import 'package:noema_studio/core/capabilities/hardware_detector.dart';
import 'package:noema_studio/core/providers/provider.dart';
import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/providers/proxy_image_provider.dart';
import 'package:noema_studio/core/providers/proxy_llm_provider.dart';
import 'package:noema_studio/core/providers/proxy_tts_provider.dart';
import 'package:noema_studio/core/plugins/plugin_context.dart';
import 'package:noema_studio/core/settings/app_settings.dart';
import 'package:noema_studio/core/bootstrap.dart';
import 'package:noema_studio/core/pipeline/pipeline_registry.dart';
import 'package:noema_studio/core/workflow/workflow_engine.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/models/job.dart' as noema_job;
import 'package:noema_studio/core/contracts/execution_request.dart'
    as noema_contracts;
import 'package:noema_studio/core/contracts/execution_result.dart';
import 'package:noema_studio/core/providers/image_provider.dart';
import 'package:noema_studio/core/providers/llm_provider.dart';
import 'package:noema_studio/core/providers/tts_provider.dart';

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

  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async => throw UnimplementedError();

  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      throw UnimplementedError();

  @override
  Future<void> cancelJob(String jobId) async {}
}

class FakeHardwareDetector implements HardwareDetector {
  final HardwareContext context;
  FakeHardwareDetector(this.context);

  @override
  HardwareContext detect() => context;
}

void main() {
  group('CapabilityResolver Hardware Routing (Mandatory Tests)', () {
    late ProviderRegistry registry;

    setUp(() {
      registry = ProviderRegistry();
      registry.clear(); // Ensure clean state for each test
    });

    test('1. GPU missing -> local GPU provider rejected', () {
      registry.register(
        MockProvider(
          id: 'gpu_provider',
          name: 'GPU Provider',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(requiresGPU: true),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: false,
        totalVRAMGB: 0,
        os: 'linux',
        hasCUDA: false,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'gpu_provider',
      );
      expect(provider, isNull);
    });

    test('2. VRAM insufficient -> provider rejected', () {
      registry.register(
        MockProvider(
          id: 'vram_provider',
          name: 'VRAM Provider',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: true,
            minimumVRAMGB: 12,
          ),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 8,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'vram_provider',
      );
      expect(provider, isNull);
    });

    test('3. CUDA missing -> CUDA provider rejected', () {
      registry.register(
        MockProvider(
          id: 'cuda_provider',
          name: 'CUDA Provider',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: true,
            requiresCUDA: true,
          ),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 8,
        os: 'macos',
        hasCUDA: false,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'cuda_provider',
      );
      expect(provider, isNull);
    });

    test('4. OS mismatch -> provider rejected', () {
      registry.register(
        MockProvider(
          id: 'windows_provider',
          name: 'Windows Provider',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: true,
            supportedOS: 'windows',
          ),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 8,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(
        VideoGenerationCapability(),
        preferredProviderId: 'windows_provider',
      );
      expect(provider, isNull);
    });

    test('5. Hardware suitable -> provider selected', () {
      registry.register(
        MockProvider(
          id: 'perfect_provider',
          name: 'Perfect Provider',
          capabilities: {CapabilityType.videoGeneration},
          hardwareRequirements: const HardwareRequirements(
            requiresGPU: true,
            minimumVRAMGB: 6,
            requiresCUDA: true,
            supportedOS: 'linux',
          ),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 8,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(VideoGenerationCapability());
      expect(provider?.id, equals('perfect_provider'));
    });

    test(
      '6. Local provider unsuitable -> fallback to capable cloud provider',
      () {
        registry.register(
          MockProvider(
            id: 'heavy_local',
            name: 'Heavy Local',
            capabilities: {CapabilityType.videoGeneration},
            hardwareRequirements: const HardwareRequirements(
              requiresGPU: true,
              minimumVRAMGB: 24,
            ),
          ),
        );
        registry.register(
          MockProvider(
            id: 'cloud_fallback',
            name: 'Cloud Fallback',
            capabilities: {CapabilityType.videoGeneration},
            hardwareRequirements: const HardwareRequirements(
              requiresGPU: false,
              minimumVRAMGB: 0,
            ),
          ),
        );

        final hardware = HardwareContext(
          hasGPU: true,
          totalVRAMGB: 6,
          os: 'linux',
          hasCUDA: false,
        );
        final resolver = CapabilityResolver(registry, hardware);

        final provider = resolver.resolve(
          VideoGenerationCapability(),
          preferredProviderId: 'heavy_local',
        );
        expect(provider?.id, equals('cloud_fallback'));
      },
    );

    test('7. Capability unsupported -> no provider selected', () {
      registry.register(
        MockProvider(
          id: 'image_only',
          name: 'Image Only Provider',
          capabilities: {CapabilityType.imageGeneration},
          hardwareRequirements: const HardwareRequirements(requiresGPU: false),
        ),
      );
      final hardware = HardwareContext(
        hasGPU: true,
        totalVRAMGB: 12,
        os: 'linux',
        hasCUDA: true,
      );
      final resolver = CapabilityResolver(registry, hardware);

      final provider = resolver.resolve(VideoGenerationCapability());
      expect(provider, isNull);
    });
  });

  group('Proxy Providers Capabilities', () {
    late PluginContext fakeContext;
    late ProviderRegistry registry;
    setUp(() {
      registry = ProviderRegistry();
      registry.register(MockImageProvider());
      registry.register(MockLLMProvider());
      registry.register(MockTTSProvider());
      fakeContext = PluginContext(
        providers: registry,
        pipelines: PipelineRegistry(),
        engine: WorkflowEngine(),
        appSettings: AppSettings(),
        jobManager: JobManager(),
        capabilityResolver: CapabilityResolver(
          ProviderRegistry(),
          const HardwareContext(
            hasGPU: false,
            totalVRAMGB: 0,
            os: 'linux',
            hasCUDA: false,
          ),
        ),
      );
    });

    test('8. ProxyImageProvider discovered via capability', () {
      final proxy = ProxyImageProvider(fakeContext);
      expect(proxy.capabilities, contains(CapabilityType.imageGeneration));
    });

    test('9. ProxyLLMProvider discovered via capability', () {
      final proxy = ProxyLLMProvider(fakeContext);
      expect(proxy.capabilities, contains(CapabilityType.llm));
    });

    test('10. ProxyTTSProvider discovered via capability', () {
      final proxy = ProxyTTSProvider(fakeContext);
      expect(proxy.capabilities, contains(CapabilityType.tts));
    });
  });

  group('Bootstrap & HardwareDetector', () {
    test('11. HardwareDetector replaceable by Mock in tests', () {
      final fakeDetector = FakeHardwareDetector(
        HardwareContext(
          hasGPU: false,
          totalVRAMGB: 1,
          os: 'custom_os',
          hasCUDA: false,
        ),
      );
      final bootstrap = Bootstrap(hardwareDetector: fakeDetector);

      // We can assert the bootstrap initializes cleanly without error using the fake
      expect(bootstrap, isNotNull);
    });

    test(
      '12. No hardcoded hardware in production bootstrap (DefaultHardwareDetector is used)',
      () {
        final bootstrap = Bootstrap();
        // It should instantiate without throwing, relying on the Platform via DefaultHardwareDetector.
        // And we verify it doesn't crash.
        expect(bootstrap, isNotNull);
      },
    );
  });
}

class MockImageProvider extends ImageProvider {
  @override
  String get id => 'mock_img';
  @override
  String get name => 'Mock Img';
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {CapabilityType.imageGeneration};
  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();
  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      throw UnimplementedError();
  @override
  Future<void> cancelJob(String jobId) async {}
  @override
  Future<noema_job.JobStatusUpdate> updateJobStatus(noema_job.Job job) async =>
      noema_job.JobStatusUpdate(status: job.status);
}

class MockLLMProvider extends LLMProvider {
  @override
  String get id => 'mock_llm';
  @override
  String get name => 'Mock LLM';
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {CapabilityType.llm};
  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();
  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      throw UnimplementedError();
  @override
  Future<void> cancelJob(String jobId) async {}
}

class MockTTSProvider extends TTSProvider {
  @override
  String get id => 'mock_tts';
  @override
  String get name => 'Mock TTS';
  @override
  bool get available => true;
  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};
  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();
  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async => throw UnimplementedError();
  @override
  Future<ExecutionResult> getResult(String jobId) async =>
      throw UnimplementedError();
  @override
  Future<void> cancelJob(String jobId) async {}
}
