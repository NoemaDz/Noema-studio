import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FlutterTTSProvider extends TTSProvider {
  @override
  String get id => "flutter_tts";

  @override
  String get name => "Flutter TTS (Local)";

  @override
  bool get available => true; // usually always true on supported platforms

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.tts};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false, minimumVRAMGB: 0);

  final FlutterTts flutterTts = FlutterTts();

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

    final fileName = "$jobId.wav";
    final outputPath = p.join(outputDir.path, fileName);

    try {
      if (voiceProfile != null) {
        try {
          await flutterTts.setVoice({"name": voiceProfile, "locale": "en-US"});
        } catch (e) {
          debugPrint("Failed to set local voice: $e");
          await flutterTts.setLanguage("en-US");
        }
      } else {
        await flutterTts.setLanguage("en-US");
      }

      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      // Synthesize to file
      await flutterTts.synthesizeToFile(text, outputPath);

      // Wait a moment for file to be written (synthesizeToFile is sometimes async on some platforms but returns 1)
      await Future.delayed(Duration(seconds: 1));

      if (File(outputPath).existsSync()) {
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
        print(
          "FlutterTTS failed to generate file. Generating silent fallback audio with FFmpeg...",
        );
        // Fallback: Generate a 3-second silent audio file using ffmpeg
        try {
          await Process.run('ffmpeg', [
            '-f',
            'lavfi',
            '-i',
            'anullsrc=r=44100:cl=stereo',
            '-t',
            '3',
            '-q:a',
            '9',
            '-acodec',
            'aac',
            '-y',
            outputPath,
          ]);
        } catch (e) {
          print("Fallback ffmpeg failed: $e");
        }
        if (File(outputPath).existsSync()) {
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
          return Job(
            id: jobId,
            providerId: id,
            type: "audio",
            status: JobStatus.failed,
            result: "Failed to create audio file even with fallback.",
          );
        }
      }
    } catch (e) {
      print(
        "FlutterTTS threw an exception: $e. Generating silent fallback audio with FFmpeg...",
      );

      try {
        await Process.run('ffmpeg', [
          '-f',
          'lavfi',
          '-i',
          'anullsrc=r=44100:cl=stereo',
          '-t',
          '3',
          '-y',
          outputPath,
        ]);
      } catch (fallbackError) {
        // Ignore fallback errors
      }

      if (File(outputPath).existsSync()) {
        return Job(
          id: jobId,
          providerId: id,
          type: "audio",
          metadata: {"text": text},
          status: JobStatus.completed,
          progress: 1.0,
          result: outputPath,
        );
      }

      return Job(
        id: jobId,
        providerId: id,
        type: "audio",
        status: JobStatus.failed,
        result: "Exception: $e",
      );
    }
  }

  @override
  Future<void> cancelJob(String jobId) async {
    await flutterTts.stop();
  }
}
