import 'dart:io';
import 'package:flutter/foundation.dart';
import '../contracts/pipeline_stage.dart';
import '../../cancellation_token.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/video_provider.dart';
import '../../job_manager.dart';
import '../../../workflows/video/i2v_workflow.dart';
import '../../../models/generated_video.dart';
import '../../../models/job.dart';
import '../../../models/scene.dart';
import '../../settings/app_settings.dart';
import '../../../models/artifact.dart';
import '../../../models/artifact_type.dart';

class SceneVideoStage extends PipelineStage {
  @override
  int get priority => 60; // After Image (50) and before Compilation (70)

  @override
  bool get requiresGPU => true;

  final WorkflowEngine engine;
  final VideoProvider provider;
  final JobManager jobManager;
  final AppSettings appSettings;

  SceneVideoStage({
    required this.engine,
    required this.provider,
    required this.jobManager,
    required this.appSettings,
  });

  @override
  Future<void> run(NoemaProject project) async {
    if (!appSettings.enableVideoGeneration) {
      debugPrint("SceneVideoStage: Skipping (enableVideoGeneration is false)");
      return;
    }
    for (final scene in project.story.scenes) {
      await runForScene(project, scene);
    }
  }

  @override
  Future<void> runForScene(NoemaProject project, Scene scene) async {
    if (!appSettings.enableVideoGeneration) {
      return;
    }

    final prompt = scene.imagePrompt ?? scene.description;

    // Find the generated image for this scene to use as the source
    final image = project.images.cast<dynamic>().firstWhere(
      (img) => img.sceneId == scene.id,
      orElse: () => null,
    );

    if (image == null ||
        image.artifact == null ||
        image.artifact.path.isEmpty) {
      debugPrint(
        'SceneVideoStage: WARNING - No source image found for scene ${scene.id}. Skipping video generation.',
      );
      return;
    }

    final currentSourceImage = image.artifact.path;

    // Check if a valid video already exists for this scene
    final existingVideo = project.videos
        .where((vid) => vid.sceneId == scene.id)
        .lastOrNull;
    if (existingVideo != null && existingVideo.artifact?.path != null) {
      if (File(existingVideo.artifact!.path).existsSync()) {
        bool isValid = true;

        if (existingVideo.sourceImagePath != currentSourceImage) {
          isValid = false;
        } else {
          final job =
              project.savedJobs
                  .where((j) => j.id == existingVideo.jobId)
                  .lastOrNull ??
              jobManager.find(existingVideo.jobId);
          if (job != null) {
            final jobPrompt = job.metadata['prompt'];
            final jobModel = job.metadata['modelName'];
            final currentModel = provider.id == 'gemini_video'
                ? appSettings.geminiVideoModel
                : provider.id;

            if (jobPrompt != prompt || job.providerId != provider.id) {
              isValid = false;
            } else if (jobModel != null && jobModel != currentModel) {
              isValid = false;
            }
          }
        }

        if (isValid) {
          debugPrint(
            'SceneVideoStage: Skipped scene ${scene.id}, valid video already exists.',
          );
          return;
        }
      }
    }

    debugPrint('SceneVideoStage: Processing scene ${scene.id}...');
    final workflow = I2vWorkflow(provider);
    final context = WorkflowContext();

    context.set('prompt', prompt);
    context.set('imagePath', currentSourceImage);
    context.set('options', scene.extras);

    try {
      final result = await engine.runWithContext(workflow, context);
      final job = result.get<Job>('video');
      if (job != null) {
        job.metadata['title'] = 'Generating Scene ${scene.id} Video (I2V)';
        jobManager.add(job);
        project.jobIds.add(job.id);
        project.videos.add(
          GeneratedVideo(
            sceneId: scene.id,
            jobId: job.id,
            sourceImagePath: image.artifact.path,
          ),
        );
        debugPrint('SceneVideoStage: Scene ${scene.id} video job queued ✓');

        // Wait for job to complete
        try {
          await jobManager.waitForCompletion(job.id, token: cancellationToken);
        } on CancelledException {
          debugPrint(
            'SceneVideoStage: Cancellation requested, killing job ${job.id} on provider.',
          );
          await jobManager.cancelJob(job.id);
          rethrow;
        }
        if (job.status == JobStatus.failed) {
          throw Exception(
            "Video generation failed for scene ${scene.id}: ${job.error?.message ?? 'Unknown error'}",
          );
        }

        final execResult = await provider.getResult(job.id);
        if (!execResult.isSuccess || execResult.textOutput == null) {
          throw Exception(
            'Failed to retrieve video artifact for scene ${scene.id}: ${execResult.error?.message ?? 'Unknown error'}',
          );
        }

        final artifact = Artifact(
          id: job.id,
          path: execResult.textOutput!,
          type: ArtifactType.video,
        );

        for (final vid in project.videos) {
          if (vid.jobId == job.id) {
            vid.artifact = artifact;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('SceneVideoStage: ERROR scene ${scene.id}: $e');
      rethrow;
    }
  }
}
