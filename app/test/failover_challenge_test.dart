import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/models/scene.dart';
import 'package:noema_studio/models/character.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_plugin.dart';
import 'package:noema_studio/infrastructure/ollama/ollama_plugin.dart';
import 'package:noema_studio/infrastructure/openai/openai_plugin.dart';
import 'package:noema_studio/infrastructure/tts/flutter_tts_plugin.dart';
import 'package:noema_studio/infrastructure/ffmpeg/ffmpeg_plugin.dart';
import 'package:noema_studio/core/plugins/core_pipeline_plugin.dart';
import 'package:noema_studio/core/plugins/ingestion_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:noema_studio/main.dart';
import 'package:noema_studio/core/cancellation_token.dart';
import 'package:noema_studio/models/generation_state.dart';

void main() {
  test(
    'Integration Failover Test: Cancel mid-generation and resume (State Persistence)',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      SharedPreferences.setMockInitialValues({
        'performance_mode': 'fast',
        'auto_detect_hardware': false,
        'image_resolution': '512x512',
      });
      HttpOverrides.global = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return Directory.systemTemp.path;
            },
          );

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

      print("--- [FAILOVER CHALLENGE START] ---");
      noema.bootstrap.jobMonitor.start();

      print("1. Building NoemaProject with 10 distinct scenes...");
      final char = Character(
        id: "char_test",
        name: "TestChar",
        description: "Test character",
        prompt: "A test character",
        imagePath: "dummy.png",
      );

      final scenes = List.generate(
        10,
        (i) => Scene(
          id: i + 1,
          description: "A beautiful landscape scene number ${i + 1}",
          narration: "This is scene number ${i + 1}.",
          dialogue: [],
          characterNames: ["TestChar"],
        ),
      );

      final project = NoemaProject(
        id: "failover_proj",
        idea: "Failover Test",
        story: Story(title: "The Great Failover", scenes: scenes),
      );
      project.characters.add(char);

      print("2. Starting Production Pipeline WITH CANCELLATION...");
      
      final token1 = CancellationToken();
      
      // Cancel the pipeline after exactly 5 seconds.
      // This will interrupt the RetryPolicy waiting for ComfyUI.
      Future.delayed(const Duration(seconds: 5), () {
        print("\n\n>>> 🛑 INJECTING CANCEL SIGNAL NOW! 🛑 <<<\n\n");
        token1.cancel();
      });

      bool caughtCancel = false;
      try {
        await noema.generateProduction(project, cancellationToken: token1, onUpdate: (status) {
          print("PIPELINE UPDATE: $status");
        });
      } on CancelledException {
        caughtCancel = true;
        print("✅ Pipeline successfully caught CancelledException and halted.");
      } catch (e) {
        fail("Pipeline failed with unexpected error: $e");
      }
      
      expect(caughtCancel, isTrue, reason: "Pipeline should have thrown CancelledException.");
      
      int completedImages = project.images.length;
      int completedAudios = project.audios.length;
      
      print("Partial State Saved: $completedImages images, $completedAudios audios.");
      expect(completedImages, lessThan(10), reason: "Pipeline should not have finished all scenes.");
      expect(project.projectState, isNot(GenerationState.completed));
      
      print("\n3. Resuming Production Pipeline from where it left off...");
      
      final token2 = CancellationToken();
      try {
        await noema.generateProduction(project, cancellationToken: token2, onUpdate: (status) {
          print("RESUME UPDATE: $status");
        });
      } catch (e) {
        fail("Resumed Pipeline failed: $e");
      }
      
      print("✅ Resumed Pipeline finished successfully!");
      
      expect(project.images.length, equals(10), reason: "All 10 images should be generated.");
      expect(project.audios.length, equals(10), reason: "All 10 audios should be generated.");
      expect(project.projectState, equals(GenerationState.completed));
      expect(project.finalVideoPath, isNotNull, reason: "Final video should be compiled.");
      
      print("\n--- [RESULTS] ---");
      print("Final Video: ${project.finalVideoPath}");
      
      noema.bootstrap.jobMonitor.stop();
      print("--- [FAILOVER CHALLENGE END] ---");
    },
    skip: Platform.environment.containsKey('CI') ? 'Requires local ComfyUI to be running' : false,
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
