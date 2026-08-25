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
import 'package:noema_studio/core/providers/async_provider.dart';
import 'package:noema_studio/main.dart'; // Ensure global noema is used

void main() {
  test(
    'Full-Body Consistency Challenge — IP-Adapter + FaceDetailer + PersonDetailer',
    skip: Platform.environment.containsKey('CI')
        ? 'Requires local ComfyUI to be running'
        : false,
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

      print("--- [FULL-BODY CONSISTENCY CHALLENGE START] ---");
      noema.bootstrap.jobMonitor.start();

      // Step 1: Generate Reference Portrait
      print("1. Generating Reference Portrait for 'Sami'...");
      final refJob = await noema.generateImage(
        "Sami, handsome young Arab man, short black hair, brown eyes, "
        "strong jawline, portrait photo, highly detailed face, photorealistic",
      );
      noema.bootstrap.jobManager.add(refJob);
      await noema.bootstrap.jobManager.waitForCompletion(refJob.id);

      final provider =
          noema.bootstrap.providerRegistry.get('comfyui') as AsyncProvider;
      final refAsset = await provider.downloadAsset(refJob.id);

      if (refAsset == null) {
        throw Exception(
          "Failed to generate reference image! Status: ${refJob.status}",
        );
      }

      final samiImagePath = refAsset;
      print("Reference portrait generated at: ${samiImagePath.path}");

      // Step 2: Build project with diverse full-body scenes
      print("2. Building full-body consistency project...");
      final character = Character(
        id: "sami_01",
        name: "Sami",
        description:
            "Handsome young Arab man with short black hair and brown eyes.",
        prompt: "Sami, handsome young Arab man, short black hair, brown eyes.",
        imagePath: samiImagePath.path,
      );

      // Scene A: Traditional outfit in desert — full body wide shot
      final sceneA = Scene(
        id: 1,
        description:
            "Full body wide shot of Sami wearing a white thobe "
            "standing in the middle of a vast golden desert at sunset, "
            "cinematic lighting, dramatic sky",
        narration: "",
        dialogue: [],
        characterNames: ["Sami"],
      );

      // Scene B: Modern casual outfit in city — medium full body
      final sceneB = Scene(
        id: 2,
        description:
            "Sami in casual jeans and blue shirt walking through "
            "a busy modern city street, medium shot showing full body, "
            "urban environment, golden hour",
        narration: "",
        dialogue: [],
        characterNames: ["Sami"],
      );

      // Scene C: Action pose on horseback — extreme wide shot
      final sceneC = Scene(
        id: 3,
        description:
            "Extreme wide shot of Sami riding a white horse "
            "through a green valley, full body visible, medieval setting, "
            "epic cinematic scene, dust and motion",
        narration: "",
        dialogue: [],
        characterNames: ["Sami"],
      );

      final project = NoemaProject(
        id: "full_body_consistency_test",
        idea: "Testing full-body character consistency across diverse scenes.",
        story: Story(
          title: "The Journey of Sami",
          scenes: [sceneA, sceneB, sceneC],
        ),
      );

      project.characters.add(character);

      print(
        "3. Executing Production Pipeline (FaceDetailer + PersonDetailer)...",
      );
      try {
        final finishedProject = await noema.generateProduction(project);
        print("Pipeline finished successfully!");

        print("\n--- [RESULTS] ---");
        print("Reference Portrait: file://${samiImagePath.path}");
        for (final img in finishedProject.images) {
          print(
            "Scene [${img.sceneId}]: file://${img.asset?.path ?? 'FAILED'}",
          );
        }
      } catch (e) {
        print("Pipeline error: $e");
      } finally {
        noema.bootstrap.jobMonitor.stop();
      }
      print("--- [FULL-BODY CONSISTENCY CHALLENGE END] ---");
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
