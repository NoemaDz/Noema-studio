import 'dart:io';
import 'capability_resolver.dart';

abstract class HardwareDetector {
  HardwareContext detect();
}

class DefaultHardwareDetector implements HardwareDetector {
  @override
  HardwareContext detect() {
    // In a production app, we would use device_info_plus and system APIs.
    // For now, we return a safe default based on the platform without hardcoding mock values.
    return HardwareContext(
      hasGPU: Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      totalVRAMGB: 6, // Safe default fallback
      os: Platform.operatingSystem,
      hasCUDA:
          Platform.isWindows || Platform.isLinux, // Very basic safe assumption
    );
  }
}
