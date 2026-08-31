import 'package:flutter/foundation.dart';
import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/image_provider.dart';
import '../../job_manager.dart';
import '../../../workflows/image/image_workflow.dart';
import '../../../models/generated_image.dart';
import '../../../models/job.dart';
import '../../cancellation_token.dart';
import '../../../models/character.dart';
import '../../../models/scene.dart';
import '../../../models/artifact.dart';
import '../../../models/artifact_type.dart';

class SceneImageStage extends PipelineStage {
  @override
  int get priority => 50;

  @override
  bool get requiresGPU => true;

  final WorkflowEngine engine;
  final ImageProvider provider;
  final JobManager jobManager;

  SceneImageStage({
    required this.engine,
    required this.provider,
    required this.jobManager,
  });

  /// Full run — processes ALL scenes (used when called outside DAG context).
  @override
  Future<void> run(NoemaProject project) async {
    project.images.clear();
    for (final scene in project.story.scenes) {
      await runForScene(project, scene);
    }
  }

  /// Per-scene run — used by [ProjectPipeline] for parallel DAG execution.
  @override
  Future<void> runForScene(NoemaProject project, Scene scene) async {
    debugPrint('SceneImageStage: Processing scene ${scene.id}...');
    final workflow = ImageWorkflow(provider);
    final context = WorkflowContext();

    context.set('prompt', scene.imagePrompt ?? scene.description);

    final List<Map<String, dynamic>> characterRefs = [];
    for (final charName in scene.characterNames) {
      final character = project.characters.cast<Character?>().firstWhere(
        (c) => c?.name == charName,
        orElse: () => null,
      );
      if (character != null && character.imagePath != null) {
        characterRefs.add({
          'name': character.name,
          'imagePath': character.imagePath,
          'position': scene.characterPositions[character.name] ?? 'center',
        });
      }
    }
    scene.extras['characters'] = characterRefs;
    context.set('options', scene.extras);

    try {
      await _submitAndWait(workflow, context, scene, project);
    } catch (e) {
      // ── IPAdapter Automatic Fallback ─────────────────────────────────────
      // If the job failed because IPAdapter models are not installed on this
      // machine, retry transparently with text_to_image (no characters).
      // This makes the app "Plug & Play" regardless of model availability.
      final errorStr = e.toString();
      final isIpAdapterError =
          errorStr.contains('modelNotFound') ||
          errorStr.contains('IPAdapter') ||
          errorStr.contains('IPAdapterUnifiedLoader') ||
          errorStr.contains('ip_adapter');

      if (isIpAdapterError && characterRefs.isNotEmpty) {
        debugPrint(
          'SceneImageStage: IPAdapter model missing for scene ${scene.id}. '
          'Retrying with text_to_image fallback (no character refs)...',
        );

        // Remove the failed job from the project so it doesn't clutter the UI
        final failedJobId = project.images
            .firstWhere((img) => img.sceneId == scene.id)
            .jobId;
        project.jobIds.remove(failedJobId);
        // Note: We leave it in JobManager in case other things reference it,
        // but removing it from project.jobIds hides it from LiveProgressTracker.

        // Strip character refs so ComfyUIDriver picks text_to_image workflow
        scene.extras['characters'] = <Map<String, dynamic>>[];
        final fallbackContext = WorkflowContext();
        fallbackContext.set('prompt', scene.imagePrompt ?? scene.description);
        fallbackContext.set('options', scene.extras);
        try {
          await _submitAndWait(workflow, fallbackContext, scene, project);
        } catch (fallbackErr) {
          debugPrint(
            'SceneImageStage: Fallback also failed for scene ${scene.id}: $fallbackErr',
          );
          rethrow;
        }
      } else {
        debugPrint('SceneImageStage: ERROR scene ${scene.id}: $e');
        rethrow;
      }
    }
  }

  /// Submits the image job and waits for completion.
  Future<void> _submitAndWait(
    ImageWorkflow workflow,
    WorkflowContext context,
    Scene scene,
    NoemaProject project,
  ) async {
    final result = await engine.runWithContext(workflow, context);
    final job = result.get<Job>('image');
    if (job != null) {
      job.metadata['title'] = 'Generating Scene ${scene.id} Image';
      jobManager.add(job);
      project.jobIds.add(job.id);

      // Only add a new GeneratedImage entry if not already tracked
      final alreadyTracked = project.images.any(
        (img) => img.sceneId == scene.id,
      );
      if (!alreadyTracked) {
        project.images.add(
          GeneratedImage(
            sceneId: scene.id,
            jobId: job.id,
            prompt: scene.description,
          ),
        );
      } else {
        // Update the existing entry's jobId (fallback re-submission)
        for (final img in project.images) {
          if (img.sceneId == scene.id) {
            img.jobId = job.id;
            break;
          }
        }
      }
      debugPrint('SceneImageStage: Scene ${scene.id} job queued ✓');

      // Wait for job to complete
      try {
        await jobManager.waitForCompletion(job.id, token: cancellationToken);
      } on CancelledException {
        debugPrint(
          'SceneImageStage: Cancellation requested, killing job ${job.id} on provider.',
        );
        await provider.cancelJob(job.id);
        rethrow;
      }

      if (job.status == JobStatus.failed) {
        throw Exception(
          'Image generation failed for scene ${scene.id}: ${job.error?.message ?? 'Unknown error'}',
        );
      }

      final execResult = await provider.getResult(job.id);
      if (!execResult.isSuccess || (execResult.textOutput == null && execResult.artifact == null)) {
        throw Exception(
          'Failed to retrieve image artifact for scene ${scene.id}: ${execResult.error?.message ?? 'Unknown error'}',
        );
      }

      final artifactPath = execResult.artifact?.path ?? execResult.textOutput!;
      final artifact = Artifact(
        id: job.id,
        path: artifactPath,
        type: ArtifactType.image,
      );

      for (final img in project.images) {
        if (img.jobId == job.id) {
          img.artifact = artifact;
          break;
        }
      }
    }
  }
}
