import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema.dart';
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
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:noema_studio/core/providers/async_provider.dart';
import 'package:noema_studio/main.dart';

void main() {
  test(
    'Simulate Character Consistency (IP-Adapter)',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      HttpOverrides.global = null; // ALLOW REAL HTTP CALLS

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              return Directory.systemTemp.path;
            },
          );

      // Use global noema from main.dart
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

      print("--- [CONSISTENCY SIMULATION START] ---");
      noema.bootstrap.jobMonitor.start();

      print("1. Generating Reference Image for 'Ali'...");
      final refJob = await noema.generateImage(
        "A handsome young man named Ali, short black hair, neutral expression, high quality portrait, highly detailed face",
      );
      noema.bootstrap.jobManager.add(refJob);
      await noema.bootstrap.jobManager.waitForCompletion(refJob.id);

      final provider =
          noema.bootstrap.providerRegistry.get('comfyui') as AsyncProvider;
      final refAsset = await provider.downloadAsset(refJob.id);

      if (refAsset == null) {
        throw Exception(
          "Failed to generate reference image for Ali! Status: ${refJob.status}",
        );
      }

      final aliImagePath = refAsset;
      print("Reference image generated at: ${aliImagePath.path}");

      print("2. Building NoemaProject...");
      final character = Character(
        id: "ali_01",
        name: "Ali",
        description: "A handsome young man.",
        prompt: "A handsome young man named Ali, short black hair.",
        imagePath: aliImagePath.path, // IP-Adapter will use this!
      );

      final scene1 = Scene(
        id: 1,
        description:
            "Close-up portrait of Ali smiling warmly in a cozy cafe, drinking coffee.",
        narration: "",
        dialogue: [],
        characterNames: ["Ali"],
      );

      final scene2 = Scene(
        id: 2,
        description:
            "Full body shot of Ali running fast in a green park, wearing red sportswear, sunny day.",
        narration: "",
        dialogue: [],
        characterNames: ["Ali"],
      );

      final scene3 = Scene(
        id: 3,
        description:
            "Ali wearing a sharp black tuxedo sitting in a futuristic neon office, side profile, dramatic lighting.",
        narration: "",
        dialogue: [],
        characterNames: ["Ali"],
      );

      final project = NoemaProject(
        id: "consistency_test_proj",
        idea: "Testing character consistency.",
        story: Story(
          title: "The Adventures of Ali",
          scenes: [scene1, scene2, scene3],
        ),
      );

      project.characters.add(character);

      print("3. Executing Production Pipeline (Generating Scene Images)...");
      try {
        final finishedProject = await noema.generateProduction(project);
        print("Pipeline finished successfully!");

        print("\n--- [RESULTS] ---");
        print("Reference: file://${aliImagePath.path}");
        for (final img in finishedProject.images) {
          print(
            "Scene Image [${img.sceneId}]: file://${img.asset?.path ?? 'FAILED'}",
          );
        }
      } catch (e) {
        print("Pipeline failed: $e");
      } finally {
        noema.bootstrap.jobMonitor.stop();
      }
      print("--- [CONSISTENCY SIMULATION END] ---");
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
