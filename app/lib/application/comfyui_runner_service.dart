import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:noema_studio/core/hardware/hardware_service.dart';

enum EngineStatus { offline, starting, ready, error }

class ComfyUIRunnerService extends ChangeNotifier {
  static final ComfyUIRunnerService instance = ComfyUIRunnerService._internal();
  ComfyUIRunnerService._internal();

  Process? _process;
  EngineStatus _status = EngineStatus.offline;
  Timer? _healthCheckTimer;

  EngineStatus get status => _status;

  void _updateStatus(EngineStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      try {
        final response = await http
            .get(Uri.parse('http://127.0.0.1:8188/system_stats'))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          _updateStatus(EngineStatus.ready);
        } else {
          _updateStatus(EngineStatus.starting);
        }
      } catch (e) {
        if (e.toString().contains('Connection refused') ||
            e.toString().contains('SocketException')) {
          if (_status == EngineStatus.ready) {
            _updateStatus(EngineStatus.error);
          }
        }
      }
    });
  }

  Future<void> start() async {
    if (_status == EngineStatus.ready || _status == EngineStatus.starting) {
      return;
    }

    _updateStatus(EngineStatus.starting);

    // 1. Forcefully kill any orphaned process on port 8188 before starting
    debugPrint("Cleaning up any existing ComfyUI instances...");
    if (!Platform.isWindows) {
      try {
        await Process.run('sh', ['-c', 'lsof -ti:8188 | xargs kill -9']);
      } catch (_) {}
    } else {
      try {
        await Process.run('cmd', [
          '/c',
          "FOR /F \"tokens=5\" %a in ('netstat -ano ^| findstr :8188') do taskkill /f /pid %a",
        ]);
      } catch (_) {}
    }

    // Give it a brief moment to release the port
    await Future.delayed(const Duration(seconds: 1));

    try {
      final appDir = await getApplicationSupportDirectory();
      final installDir = p.join(appDir.path, 'noema', 'comfyui');

      final mainPy = File(p.join(installDir, 'main.py'));
      if (!mainPy.existsSync()) {
        debugPrint("ComfyUI main.py not found. Cannot start runner.");
        _updateStatus(EngineStatus.error);
        return;
      }

      String pythonExecutable = Platform.isWindows ? 'python' : 'python3';
      final venvPython = Platform.isWindows
          ? File(p.join(installDir, 'venv', 'Scripts', 'python.exe'))
          : File(p.join(installDir, 'venv', 'bin', 'python'));

      if (venvPython.existsSync()) {
        pythonExecutable = venvPython.path;
      }

      debugPrint("Starting ComfyUI in background using $pythonExecutable...");

      final hwInfo = await HardwareService().detectHardware();
      final List<String> args = ['main.py', '--port', '8188'];
      
      if (!hwInfo.isUnknown) {
        if (hwInfo.vramMB <= 6144) {
          // Low VRAM (<= 6GB): aggressive compression but NO FP8 UNet to preserve quality
          args.addAll([
            '--lowvram',
            '--fp8_e4m3fn-text-enc',
            '--disable-dynamic-vram',
          ]);
        } else if (hwInfo.vramMB <= 8192) {
          // Medium VRAM (8GB)
          args.addAll([
            '--lowvram',
            '--fp8_e4m3fn-text-enc',
          ]);
        } else {
          // High VRAM (12GB+)
          args.addAll([
            '--highvram',
          ]);
        }
      } else {
        // Fallback for unknown hardware
        args.addAll([
            '--lowvram',
            '--fp8_e4m3fn-text-enc',
            '--disable-dynamic-vram',
        ]);
      }

      _process = await Process.start(pythonExecutable, args, workingDirectory: installDir);

      debugPrint("ComfyUI Process Started (PID: ${_process!.pid})");

      _process!.stderr.listen((data) {
        debugPrint("ComfyUI ERR: ${String.fromCharCodes(data)}");
      });

      _process!.stdout.listen((data) {
        // Drain stdout to prevent pipe buffer from filling up and blocking Python
      });

      _process!.exitCode.then((code) {
        debugPrint("ComfyUI Process Exited with code $code");
        _process = null;
        _healthCheckTimer?.cancel();
        _updateStatus(EngineStatus.offline);
      });

      _startHealthCheck();
    } catch (e) {
      debugPrint("Failed to start ComfyUI Runner: $e");
      _updateStatus(EngineStatus.error);
    }
  }

  void stop() {
    _healthCheckTimer?.cancel();

    debugPrint("Killing ComfyUI Process...");
    if (_process != null) {
      _process!.kill(ProcessSignal.sigkill);
      _process = null;
    }

    // Forcefully kill any orphaned process on port 8188
    if (!Platform.isWindows) {
      Process.run('sh', [
        '-c',
        'lsof -ti:8188 | xargs kill -9',
      ]).catchError((_) => ProcessResult(0, -1, '', ''));
    } else {
      Process.run('cmd', [
        '/c',
        "FOR /F \"tokens=5\" %a in ('netstat -ano ^| findstr :8188') do taskkill /f /pid %a",
      ]).catchError((_) => ProcessResult(0, -1, '', ''));
    }

    _updateStatus(EngineStatus.offline);
  }
}
