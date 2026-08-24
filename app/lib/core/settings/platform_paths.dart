import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A centralized singleton for managing all application paths.
/// Ensures Noema Studio is cross-platform and doesn't rely on hardcoded paths.
class PlatformPaths {
  static final PlatformPaths instance = PlatformPaths._internal();
  PlatformPaths._internal();

  String? _baseAppDataPath;

  /// Initializes the base application data directory.
  /// Must be called during app bootstrap.
  Future<void> init() async {
    final supportDir = await getApplicationSupportDirectory();
    _baseAppDataPath = p.join(supportDir.path, 'noema');

    // Ensure core directories exist
    await _ensureDirExists(appDataDirectory);
    await _ensureDirExists(projectsDirectory);
    await _ensureDirExists(binariesDirectory);
    await _ensureDirExists(modelsDirectory);
  }

  /// The root directory for all Noema Studio data.
  String get appDataDirectory {
    if (_baseAppDataPath == null) {
      throw StateError("PlatformPaths not initialized. Call init() first.");
    }
    return _baseAppDataPath!;
  }

  /// Directory where user projects are saved.
  String get projectsDirectory => p.join(appDataDirectory, 'projects');

  /// Directory for portable binaries (e.g., ffmpeg, git, ComfyUI).
  String get binariesDirectory => p.join(appDataDirectory, 'bin');

  /// Directory for downloaded AI models.
  String get modelsDirectory => p.join(appDataDirectory, 'models');

  /// Generates a unique output path for a specific project/job.
  String getJobOutputPath(String jobId) {
    final path = p.join(appDataDirectory, 'output', jobId);
    _ensureDirExistsSync(path);
    return path;
  }

  Future<void> _ensureDirExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  void _ensureDirExistsSync(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
}
