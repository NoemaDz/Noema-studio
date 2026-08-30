enum CapabilityType { imageGeneration, videoGeneration, tts, lipSync, sfx }

class HardwareRequirements {
  final bool requiresGPU;
  final int minimumVRAMGB;

  const HardwareRequirements({
    this.requiresGPU = false,
    this.minimumVRAMGB = 0,
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
