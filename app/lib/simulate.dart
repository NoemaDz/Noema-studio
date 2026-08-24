import 'dart:io';
import 'package:flutter/material.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_plugin.dart';
import 'package:noema_studio/infrastructure/ollama/ollama_plugin.dart';
import 'package:noema_studio/infrastructure/openai/openai_plugin.dart';
import 'package:noema_studio/infrastructure/tts/flutter_tts_plugin.dart';
import 'package:noema_studio/infrastructure/ffmpeg/ffmpeg_plugin.dart';
import 'package:noema_studio/core/plugins/core_pipeline_plugin.dart';
import 'package:noema_studio/core/plugins/ingestion_plugin.dart';

import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/application/project_synchronizer.dart';

import 'package:noema_studio/main.dart' show noema;
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  final pdfPath = 'story.pdf';
  print("--- [SIMULATION START] ---");
  print("Ingesting PDF: $pdfPath...");

  try {
    final text = await noema.documentIngestionService.importDocument(pdfPath);
    print("Extracted text: $text");

    print("Generating project (this may take a few minutes)...");
    final p = NoemaProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      idea: text,
      story: Story(title: "Simulating", scenes: []),
    );
    final project = await noema.generateProject(p);

    print(
      "Project generated successfully! Waiting for background jobs (Images, Audio, Video)...",
    );

    // Attach the synchronizer to trigger video generation when images/audio are ready
    final synchronizer = ProjectSynchronizer(
      project: project,
      provider: noema.bootstrap.imageProvider,
      state: noema.bootstrap.projectState,
    );
    synchronizer.attach(noema.bootstrap.jobEvents);

    // In our quick CLI script, we must loop to keep the process alive
    int emptyJobsCounter = 0;
    while (project.finalVideoPath == null) {
      if (project.jobs.isEmpty) {
        emptyJobsCounter++;
        if (emptyJobsCounter > 5) {
          print(
            "Error: No jobs were generated. Check the LLM output or JSON parsing.",
          );
          break;
        }
      } else {
        emptyJobsCounter = 0;
      }

      bool anyFailed = project.jobs.any((j) => j.status == JobStatus.failed);
      if (anyFailed) {
        print("Error: A background job failed.");
        break;
      }

      bool allJobsDone =
          project.jobs.isNotEmpty &&
          project.jobs.every((j) => j.status == JobStatus.completed);
      if (allJobsDone &&
          project.finalVideoPath == null &&
          project.jobs.any((j) => j.type == "video_compile")) {
        // Video job completed but path not updated? Handled by synchronizer.
        // If we get here, give the synchronizer a tick to update it.
      }

      await Future.delayed(const Duration(seconds: 2));
      print(
        "Waiting... Active jobs: ${project.jobs.where((j) => j.status == JobStatus.running || j.status == JobStatus.queued).length} / ${project.jobs.length}",
      );
    }

    print("Video generated at: ${project.finalVideoPath}");

    print("--- [SIMULATION END] ---");
  } catch (e, stacktrace) {
    print("ERROR DURING SIMULATION: $e");
    print(stacktrace);
  }
  print("--- [SIMULATION END] ---");
  exit(0);
}
