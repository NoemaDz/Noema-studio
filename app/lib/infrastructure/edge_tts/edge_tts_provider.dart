import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/providers/tts_provider.dart';
import '../../models/job.dart';
import '../../main.dart';

class EdgeTTSProvider extends TTSProvider {
  @override
  String get id => "edge_tts";

  @override
  String get name => "Microsoft Edge TTS (Free)";

  @override
  bool get available => true;

  @override
  Future<Job> generateAudio(String text) async {
    final jobId = "tts_${DateTime.now().millisecondsSinceEpoch}";
    final appDir = await getApplicationSupportDirectory();
    final outputDir = Directory(
      p.join(appDir.path, "noema", "output", "audio"),
    );
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final fileName = "$jobId.mp3";
    final outputPath = p.join(outputDir.path, fileName);

    final voice = noema.bootstrap.appSettings.edgeTtsVoice;

    try {
      ProcessResult? result;
      final home = Platform.environment['HOME'] ?? '';
      final possiblePaths = [
        'edge-tts', // In PATH
        p.join(home, '.local', 'bin', 'edge-tts'), // pipx or pip --user
        p.join(home, 'myenv', 'bin', 'edge-tts'), // The user's myenv
        'python3', // fallback to python module
      ];

      for (final binPath in possiblePaths) {
        try {
          if (binPath == 'python3') {
            print("Trying python3 -m edge_tts...");
            result = await Process.run('python3', [
              '-m',
              'edge_tts',
              '--text',
              text,
              '--write-media',
              outputPath,
              '--voice',
              voice,
            ]);
          } else {
            print("Trying edge-tts binary at: $binPath");
            result = await Process.run(binPath, [
              '--text',
              text,
              '--write-media',
              outputPath,
              '--voice',
              voice,
            ]);
          }

          // If the command succeeded, break out of the loop
          if (result.exitCode == 0) {
            break;
          }
        } catch (e) {
          // Ignore ProcessException (command not found) and try the next one
        }
      }

      if (result != null &&
          result.exitCode == 0 &&
          File(outputPath).existsSync()) {
        return Job(
          id: jobId,
          type: "audio",
          metadata: {"text": text},
          status: JobStatus.completed,
          progress: 1.0,
          result: outputPath,
        );
      } else {
        print("Edge TTS failed with exit code: ${result?.exitCode}");
        print("stdout: ${result?.stdout}");
        print("stderr: ${result?.stderr}");
        return Job(
          id: jobId,
          type: "audio",
          status: JobStatus.failed,
          result: "Edge TTS failed: ${result?.stderr}",
        );
      }
    } catch (e) {
      print("Edge TTS Exception: $e");
      return Job(
        id: jobId,
        type: "audio",
        status: JobStatus.failed,
        result:
            "Exception: $e (Please make sure you have run 'pip install edge-tts')",
      );
    }
  }
}
