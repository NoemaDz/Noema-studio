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
import 'package:noema_studio/main.dart';

void main() {
  test(
    '10 Scenes Challenge — Different poses and clothes (IP-Adapter + Detailer)',
    skip: 'Requires Local ComfyUI Backend',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'performance_mode': 'ultra',
        'auto_detect_hardware': false,
        'image_resolution': '768x512',
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

      print("--- [10 SCENES CHALLENGE START] ---");
      noema.bootstrap.jobMonitor.start();

      print("1. Generating Reference Image for 'Sami'...");
      final refJob = await noema.generateImage(
        "A high quality studio portrait of a handsome 30 year old middle eastern man named Sami. He has short dark hair, a neat beard, and intense brown eyes. Neutral background. Cinematic lighting, highly detailed face.",
      );
      noema.bootstrap.jobManager.add(refJob);
      await noema.bootstrap.jobManager.waitForCompletion(refJob.id);

      final provider =
          noema.bootstrap.providerRegistry.get('comfyui') as AsyncProvider;
      final refAsset = await provider.getResult(refJob.id);

      if (!refAsset.isSuccess || refAsset.textOutput == null) {
        throw Exception(
          "Failed to generate reference image for Sami! Status: \${refJob.status}",
        );
      }

      final samiImagePath = refAsset.textOutput!;
      print("Reference image generated at: \$samiImagePath");

      print("2. Building NoemaProject with 10 distinct scenes...");
      final sami = Character(
        id: "char_sami",
        name: "Sami",
        description: "Handsome 30yo middle eastern man, neat beard",
        prompt:
            "Handsome 30yo middle eastern man named Sami, short dark hair, neat beard, intense brown eyes",
        imagePath: samiImagePath,
      );

      final scenePrompts = [
        "Sami sitting at a rustic cafe table in Paris, wearing a casual grey sweater. He is reading a newspaper and drinking coffee. Natural daylight.",
        "Sami running through a dense green forest, wearing a red athletic tracksuit. Dynamic angle, motion blur, intense focus.",
        "Sami standing in a modern glass office boardroom, wearing a sharp navy blue business suit and red tie. Looking out the window. Cinematic corporate lighting.",
        "Sami walking in a snowy street in New York at night, wearing a thick black winter coat and a scarf. Snowflakes falling, streetlights glowing warmly.",
        "Sami relaxing on a sunny tropical beach, wearing a white unbuttoned linen shirt and sunglasses. Ocean waves in the background.",
        "Sami standing in a neon-lit cyberpunk city alley, wearing a futuristic black leather jacket with glowing accents. Rain pouring, reflections on wet ground.",
        "Sami in a professional restaurant kitchen, wearing a white chef's uniform and apron. He is tossing vegetables in a flaming pan. Action shot.",
        "Sami riding a horse in a medieval battlefield, wearing silver knight armor. Dramatic cloudy sky, epic fantasy style.",
        "Sami sitting comfortably on a living room couch, wearing a comfortable t-shirt and sweatpants, playing a video game with a controller.",
        "Sami floating inside a futuristic space station looking at Earth through the window. He is wearing a white astronaut spacesuit, helmet off, holding it under his arm.",
      ];

      final scenes = List.generate(
        10,
        (i) => Scene(
          id: i + 1,
          description: scenePrompts[i],
          narration: "",
          dialogue: [],
          characterNames: ["Sami"],
        ),
      );

      final project = NoemaProject(
        id: "10_scenes_proj",
        idea: "Sami in 10 different universes.",
        story: Story(title: "The 10 Lives of Sami", scenes: scenes),
      );

      project.characters.add(sami);

      print("3. Executing Production Pipeline (Generating 10 Scene Images)...");
      try {
        final finishedProject = await noema.generateProduction(project);
        print("Pipeline finished successfully!");

        print("\n--- [RESULTS] ---");
        print("Reference: file://$samiImagePath");
        for (final img in finishedProject.images) {
          print(
            "Scene Image [${img.sceneId}]: file://${img.artifact?.path ?? 'FAILED'}",
          );
        }
      } catch (e) {
        fail("Pipeline failed: $e");
      } finally {
        noema.bootstrap.jobMonitor.stop();
      }
      print("--- [10 SCENES CHALLENGE END] ---");
    },
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
