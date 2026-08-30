import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/tts_provider.dart';
import '../../core/capabilities/capability.dart';
import '../../models/job.dart';
import '../../main.dart';

class OpenAITTSProvider extends TTSProvider {
  @override
  String get id => "openai_tts";

  @override
  String get name => "OpenAI TTS API";

  @override
  bool get available => noema.bootstrap.appSettings.openAiKey.isNotEmpty;

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

    final apiKey = noema.bootstrap.appSettings.openAiKey;
    final voice = voiceProfile ?? noema.bootstrap.appSettings.openAiTtsVoice;

    if (apiKey.isEmpty) {
      return Job(
        id: jobId,
        providerId: id,
        type: "audio",
        status: JobStatus.queued,
        result: "OpenAI API key is missing.",
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('https://api.openai.com/v1/audio/speech'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'model': 'tts-1', 'input': text, 'voice': voice}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);

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
          result: "OpenAI TTS failed: ${response.body}",
        );
      }
    } catch (e) {
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
  Future<void> cancelJob(String jobId) async {}
}
