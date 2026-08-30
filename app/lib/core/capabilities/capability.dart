enum CapabilityType { imageGeneration, videoGeneration, tts, lipSync, sfx, llm }

class HardwareRequirements {
  final bool requiresGPU;
  final int minimumVRAMGB;
  final bool requiresCUDA;
  final String? supportedOS;

  const HardwareRequirements({
    this.requiresGPU = false,
    this.minimumVRAMGB = 0,
    this.requiresCUDA = false,
    this.supportedOS,
  });
}

abstract class Capability {
  CapabilityType get type;
  bool get requiresGPU;
  int get requiredVRAMGB;
}

class VideoGenerationCapability extends Capability {
  @override
  final CapabilityType type = CapabilityType.videoGeneration;

  @override
  final bool requiresGPU;

  @override
  final int requiredVRAMGB;

  VideoGenerationCapability({this.requiresGPU = true, this.requiredVRAMGB = 8});
}
