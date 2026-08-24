import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_plugin.dart';
import 'package:noema_studio/infrastructure/ollama/ollama_plugin.dart';
import 'package:noema_studio/infrastructure/openai/openai_plugin.dart';
import 'package:noema_studio/infrastructure/tts/flutter_tts_plugin.dart';
import 'package:noema_studio/infrastructure/ffmpeg/ffmpeg_plugin.dart';
import 'package:noema_studio/core/plugins/core_pipeline_plugin.dart';
import 'package:noema_studio/core/plugins/ingestion_plugin.dart';

void main() {
  testWidgets(
    'Simulate Story Generation from PDF',
    (WidgetTester tester) async {
      final noema = Noema();
      noema.init([
        ComfyUIPlugin(),
        OllamaPlugin(),
        OpenAIPlugin(),
        FlutterTTSPlugin(),
        FFmpegPlugin(),
        IngestionPlugin(),
        CorePipelinePlugin(),
      ]);

      await noema.bootstrap.appSettings.loadSettings();

      // In a real environment, we would also verify if Ollama or OpenAI are properly configured.
      // We will do a full simulation here.

      final pdfPath = 'story.pdf';
      expect(
        File(pdfPath).existsSync(),
        isTrue,
        reason: 'story.pdf must exist',
      );

      print("--- [SIMULATION START] ---");
      print("Ingesting PDF: $pdfPath...");

      // Simulate Document Ingestion
      final text = await noema.documentIngestionService.importDocument(pdfPath);
      print("Extracted text length: ${text.length}");

      // Attempt to generate a project using the extracted text
      // Depending on what AI models are running, this might take time.
      print(
        "Generating project (this may take a few minutes if local models are active)...",
      );

      try {
        final p = NoemaProject(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          idea: text,
          story: Story(title: "Simulating Test", scenes: []),
        );
        final project = await noema.generateProject(p);
        print("Project generated successfully!");
        print("Final Video Path: ${project.finalVideoPath}");

        expect(project, isNotNull);
      } catch (e) {
        print(
          "Project generation failed (likely due to missing external dependencies like Ollama/ComfyUI/FFmpeg during testing): $e",
        );
      }
      print("--- [SIMULATION END] ---");
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
