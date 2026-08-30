import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../main.dart';

class EdgeTTSProvider extends TTSProvider {
  @override
  String get id => "edge_tts";

  @override
  String get name => "Microsoft Edge TTS (Free)";

  @override
  bool get available => true; // Edge TTS requires no API key

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  @override
  Future<Job> generateAudio(String text, {String? voiceProfile}) async {
    final jobId = "tts_${const Uuid().v4()}";
    final appDir = await getApplicationSupportDirectory();
    final outputDir = Directory(
      p.join(appDir.path, "noema", "output", "audio"),
    );
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final fileName = "$jobId.mp3";
    final outputPath = p.join(outputDir.path, fileName);

    final voice = voiceProfile ?? noema.bootstrap.appSettings.edgeTtsVoice;

    try {
      ProcessResult? result;
      final home = Platform.environment['HOME'] ?? '';
      final possiblePaths = [
        'edge-tts', // In PATH
        p.join(home, '.local', 'bin', 'edge-tts'), // pipx or pip --user
        p.join(home, 'myenv', 'bin', 'edge-tts'), // The user's myenv
        'python3', // fallback to python module
      ];

      final List<String> errors = [];

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

          if (result.exitCode == 0) {
            break; // Success!
          } else {
            errors.add(
              '[$binPath] exitCode: ${result.exitCode}, stderr: ${result.stderr}',
            );
          }
        } catch (e) {
          errors.add('[$binPath] exception: $e');
        }
      }

      if (result != null &&
          result.exitCode == 0 &&
          File(outputPath).existsSync()) {
        return Job(
          id: jobId,
          providerId: id,
          type: "audio",
          metadata: {"text": text},
          status: JobStatus.completed,
          progress: 1.0,
          result: outputPath,
        );
      } else {
        print("Edge TTS failed all attempts.");
        for (var err in errors) {
          print(err);
        }
        return Job(
          id: jobId,
          providerId: id,
          type: "audio",
          status: JobStatus.failed,
          result:
              "Edge TTS failed. See console for details. (Did you use Arabic text with an English voice?)",
        );
      }
    } catch (e) {
      print("Edge TTS Exception: $e");
      return Job(
        id: jobId,
        providerId: id,
        type: "audio",
        status: JobStatus.failed,
        result:
            "Exception: $e (Please make sure you have run 'pip install edge-tts')",
      );
    }
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
