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
import '../../../models/character.dart';
import '../../../models/scene.dart';

class SceneImageStage extends PipelineStage {
  @override
  int get priority => 50;

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
      final result = await engine.runWithContext(workflow, context);
      final job = result.get<Job>('image');
      if (job != null) {
        job.metadata['title'] = 'Generating Scene ${scene.id} Image';
        jobManager.add(job);
        project.jobIds.add(job.id);
        project.images.add(
          GeneratedImage(
            sceneId: scene.id,
            jobId: job.id,
            prompt: scene.description,
          ),
        );
        debugPrint('SceneImageStage: Scene ${scene.id} job queued ✓');

        // Wait for job to complete
        await jobManager.waitForCompletion(job.id, token: cancellationToken);

        if (job.status == JobStatus.failed) {
          throw Exception(
            "Image generation failed for scene ${scene.id}: ${job.result}",
          );
        }
      }
    } catch (e) {
      debugPrint('SceneImageStage: ERROR scene ${scene.id}: $e');
      rethrow;
    }
  }
}
