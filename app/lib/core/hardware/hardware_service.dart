import 'dart:io';

enum PerformanceProfile {
  fast,
  balanced,
  ultra,
}

class HardwareInfo {
  final int vramMB;
  final String gpuName;
  final PerformanceProfile recommendedProfile;

  HardwareInfo({
    required this.vramMB,
    required this.gpuName,
    required this.recommendedProfile,
  });

  bool get isUnknown => vramMB == 0;
}

class HardwareService {
  static const int _thresholdBalancedMB = 5800; // ~6GB
  static const int _thresholdUltraMB = 7800; // ~8GB

  /// Detects the hardware and returns a HardwareInfo object.
  Future<HardwareInfo> detectHardware() async {
    int vramMB = 0;
    String gpuName = 'Unknown GPU';

    try {
      if (Platform.isLinux || Platform.isWindows) {
        // Try nvidia-smi for VRAM
        final vramResult = await Process.run('nvidia-smi', [
          '--query-gpu=memory.total',
          '--format=csv,noheader,nounits'
        ]);
        
        if (vramResult.exitCode == 0) {
          final lines = vramResult.stdout.toString().trim().split('\n');
          if (lines.isNotEmpty) {
            vramMB = int.tryParse(lines.first.trim()) ?? 0;
          }
        }

        // Try nvidia-smi for GPU Name
        final nameResult = await Process.run('nvidia-smi', [
          '--query-gpu=name',
          '--format=csv,noheader'
        ]);
        
        if (nameResult.exitCode == 0) {
          final lines = nameResult.stdout.toString().trim().split('\n');
          if (lines.isNotEmpty) {
            gpuName = lines.first.trim();
          }
        }
      }
    } catch (e) {
      print("HardwareService: Failed to detect hardware - $e");
    }

    final recommended = recommendProfile(vramMB);
    
    return HardwareInfo(
      vramMB: vramMB,
      gpuName: gpuName,
      recommendedProfile: recommended,
    );
  }

  /// Recommends a performance profile based on VRAM capacity.
  static PerformanceProfile recommendProfile(int vramMB) {
    if (vramMB == 0) {
      return PerformanceProfile.fast; // Safe fallback
    } else if (vramMB >= _thresholdUltraMB) {
      return PerformanceProfile.ultra;
    } else if (vramMB >= _thresholdBalancedMB) {
      return PerformanceProfile.balanced;
    } else {
      return PerformanceProfile.fast;
    }
  }
}
