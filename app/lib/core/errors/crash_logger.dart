import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CrashLogger {
  static File? _logFile;

  static Future<File> get _file async {
    if (_logFile != null) return _logFile!;
    final directory = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(directory.path, "noema", "logs"));
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    _logFile = File(p.join(logDir.path, "noema_crash.log"));
    return _logFile!;
  }

  /// Logs an unhandled exception or crash with timestamp and stack trace.
  static Future<void> logCrash(dynamic error, StackTrace? stackTrace, {String context = 'GLOBAL'}) async {
    try {
      final file = await _file;
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '''
================================================================================
[$timestamp] CRASH DETECTED [$context]
Error: $error
StackTrace:
${stackTrace ?? 'No StackTrace available'}
================================================================================

''';
      await file.writeAsString(logEntry, mode: FileMode.append);
      debugPrint("CrashLogger: Crash written to ${file.path}");
    } catch (e) {
      debugPrint("CrashLogger Failed to write log: $e");
    }
  }

  /// Initializes global Flutter error hooks.
  static void setupGlobalErrorHandler() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logCrash(details.exception, details.stack, context: 'FLUTTER_ERROR');
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logCrash(error, stack, context: 'ASYNC_PLATFORM_ERROR');
      return true; // Prevents crash / exit
    };
  }
}
