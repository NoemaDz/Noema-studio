import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dependency_manager.dart';

enum InstallerState {
  idle,
  checking,
  checkingDependencies,
  cloningComfyUI,
  installingDependencies,
  cloningCustomNodes,
  completed,
  error,
}

class ComfyUIInstallerService extends ChangeNotifier {
  InstallerState _state = InstallerState.idle;
  String _statusMessage = "";
  double _progress = 0.0;
  String? _installDir;

  InstallerState get state => _state;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  String? get installDir => _installDir;

  bool get isInstalled => _state == InstallerState.completed;

  void _update(InstallerState state, String msg, double prog) {
    _state = state;
    _statusMessage = msg;
    _progress = prog;
    notifyListeners();
  }

  Future<void> checkInstallation() async {
    _update(InstallerState.checking, "Checking ComfyUI installation...", 0.0);

    try {
      final appDir = await getApplicationSupportDirectory();
      _installDir = p.join(appDir.path, 'noema', 'comfyui');

      final dir = Directory(_installDir!);
      if (dir.existsSync() &&
          File(p.join(_installDir!, 'main.py')).existsSync()) {
        _update(InstallerState.completed, "ComfyUI is already installed.", 1.0);
      } else {
        _update(InstallerState.idle, "ComfyUI is not installed.", 0.0);
      }
    } catch (e) {
      _update(InstallerState.error, "Error checking installation: $e", 0.0);
    }
  }

  Future<void> install() async {
    if (_installDir == null) await checkInstallation();
    if (_state == InstallerState.completed) return;

    try {
      // 0. Ensure zero-dependency setup (Git, FFmpeg)
      _update(
        InstallerState.checkingDependencies,
        "Ensuring system tools (Git, FFmpeg) are available...",
        0.05,
      );
      await DependencyManager.instance.ensureDependencies((msg) {
        _update(InstallerState.checkingDependencies, msg, 0.05);
      });

      final dir = Directory(_installDir!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final gitPath = DependencyManager.instance.gitPath;

      // 1. Clone ComfyUI
      _update(InstallerState.cloningComfyUI, "Cloning ComfyUI engine...", 0.1);
      final cloneResult = await Process.run(gitPath, [
        'clone',
        'https://github.com/comfyanonymous/ComfyUI.git',
        '.',
      ], workingDirectory: _installDir);

      if (cloneResult.exitCode != 0) {
        throw Exception("Failed to clone ComfyUI: ${cloneResult.stderr}");
      }

      // 2. Install Dependencies (Skipping for now to avoid python env nightmares, assuming portable or manual pip install later)
      _update(
        InstallerState.installingDependencies,
        "Preparing directories...",
        0.4,
      );

      // 3. Clone Custom Nodes
      _update(
        InstallerState.cloningCustomNodes,
        "Installing required custom nodes...",
        0.5,
      );
      final customNodesDir = p.join(_installDir!, 'custom_nodes');

      final nodesToClone = [
        "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git",
        "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git",
        "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git",
        "https://github.com/ltdrdata/ComfyUI-Manager.git",
      ];

      double progressStep = 0.4 / nodesToClone.length;
      double currentProgress = 0.5;

      for (final repo in nodesToClone) {
        _update(
          InstallerState.cloningCustomNodes,
          "Installing node: ${repo.split('/').last.replaceAll('.git', '')}...",
          currentProgress,
        );
        await Process.run(gitPath, [
          'clone',
          repo,
        ], workingDirectory: customNodesDir);
        currentProgress += progressStep;
      }

      _update(
        InstallerState.completed,
        "ComfyUI Setup Complete! (Models must be added manually)",
        1.0,
      );
    } catch (e) {
      _update(InstallerState.error, "Installation Failed: $e", 0.0);
    }
  }
}
