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

void main() {
  test(
    'Multi-Character Challenge — 1, 2, and 3 Characters with Regional Prompting',
    skip: Platform.environment.containsKey('CI')
        ? 'Requires local ComfyUI to be running'
        : false,
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'performance_mode': 'ultra',
        'auto_detect_hardware': false,
        'image_resolution': '1024x512',
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

      print("--- [MULTI-CHARACTER CHALLENGE START] ---");
      noema.bootstrap.jobMonitor.start();

      // Use local test assets instead of hardcoded absolute paths
      final char1Path = "test/assets/char1.jpg";
      final char2Path = "test/assets/char2.jpg";
      final char3Path = "test/assets/char3.jpg";

      // Dynamically skip if we don't have the assets downloaded locally
      if (!File(char1Path).existsSync() || !File(char2Path).existsSync() || !File(char3Path).existsSync()) {
        print("Skipping Multi-Character Challenge because local test assets are missing.");
        return;
      }
      final char1 = Character(
        id: "c1",
        name: "Man 1",
        description: "A young man with glasses",
        prompt: "A young man with glasses",
        imagePath: char1Path,
      );

      final char2 = Character(
        id: "c2",
        name: "Woman",
        description: "A blonde young woman",
        prompt: "A blonde young woman",
        imagePath: char2Path,
      );

      final char3 = Character(
        id: "c3",
        name: "Man 2",
        description: "An older man with a beard",
        prompt: "An older man with a beard",
        imagePath: char3Path,
      );

      final scenes = [
        Scene(
          id: 1,
          description: "A portrait of Man 1 sitting in a cafe.",
          narration: "",
          dialogue: [],
          characterNames: ["Man 1"],
          characterPositions: {"Man 1": "center"},
        ),
        Scene(
          id: 2,
          description: "Man 1 and Woman sitting together on a park bench. Man 1 on the left, Woman on the right.",
          narration: "",
          dialogue: [],
          characterNames: ["Man 1", "Woman"],
          characterPositions: {"Man 1": "left", "Woman": "right"},
        ),
        Scene(
          id: 3,
          description: "Man 1, Woman, and Man 2 standing in a modern office. Man 1 on the left, Woman in the center, Man 2 on the right.",
          narration: "",
          dialogue: [],
          characterNames: ["Man 1", "Woman", "Man 2"],
          characterPositions: {"Man 1": "left", "Woman": "center", "Man 2": "right"},
        ),
      ];

      final project = NoemaProject(
        id: "multi_char_proj",
        idea: "Multi character test.",
        story: Story(title: "The Team", scenes: scenes),
      );

      project.characters.addAll([char1, char2, char3]);

      print("Executing Production Pipeline (Generating 3 Multi-character Scenes)...");
      try {
        final finishedProject = await noema.generateProduction(project);
        print("Pipeline finished successfully!");

        print("\n--- [RESULTS] ---");
        for (final img in finishedProject.images) {
          print(
            "Scene Image [${img.sceneId}]: file://${img.asset?.path ?? 'FAILED'}",
          );
        }

        // Assertions for a true test
        expect(finishedProject.images.length, 3, reason: "Expected 3 generated images");
        for (final img in finishedProject.images) {
          expect(img.asset, isNotNull, reason: "Image asset should be successfully generated");
          expect(File(img.asset!.path).existsSync(), isTrue, reason: "Generated file must exist on disk");
        }
      } catch (e) {
        fail("Pipeline failed: $e");
      } finally {
        noema.bootstrap.jobMonitor.stop();
      }
      print("--- [MULTI-CHARACTER CHALLENGE END] ---");
    },
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
