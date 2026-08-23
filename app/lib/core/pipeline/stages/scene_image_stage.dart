import 'package:flutter/foundation.dart';
import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';

import '../../providers/image_provider.dart';

import '../../../workflows/image/image_workflow.dart';

import '../../../models/generated_image.dart';
import '../../../models/job.dart';
import '../../../models/character.dart';



class SceneImageStage implements PipelineStage {
  @override
  int get priority => 50;

  final WorkflowEngine engine;

  final ImageProvider provider;

  SceneImageStage({
  required this.engine,
  required this.provider,
 });


  @override
Future<void> run(
  NoemaProject project,
) async {
  project.images.clear();
  debugPrint("SceneImageStage: Starting. Cleared project.images. Story has ${project.story.scenes.length} scenes.");

  for (final scene in project.story.scenes) {
    debugPrint("SceneImageStage: Processing scene ${scene.id}...");
    final workflow = ImageWorkflow(
      provider,
    );

    final context = WorkflowContext();

    context.set(
      "prompt",
      scene.imagePrompt ?? scene.description,
    );
    
    // Pass character references and positions to options for ComfyUIDriver
    final List<Map<String, dynamic>> characterRefs = [];
    for (final charName in scene.characterNames) {
      final character = project.characters.cast<Character?>().firstWhere(
        (c) => c?.name == charName, 
        orElse: () => null,
      );
      
      if (character != null && character.imagePath != null) {
        characterRefs.add({
          "name": character.name,
          "imagePath": character.imagePath,
          "position": scene.characterPositions[character.name] ?? "center",
        });
      }
    }
    
    scene.extras["characters"] = characterRefs;
    context.set("options", scene.extras);

    try {
      debugPrint("SceneImageStage: Running ImageWorkflow for scene ${scene.id}...");
      final result = await engine.runWithContext(
        workflow,
        context,
      );

      final job = result.get<Job>("image");
      if (job != null) {
        job.metadata["title"] = "Generating Scene ${scene.id} Image";
        debugPrint("SceneImageStage: Workflow returned job ${job.id} for scene ${scene.id}. Adding to project.");
        project.jobs.add(job);
        project.images.add(
          GeneratedImage(
            sceneId: scene.id,
            jobId: job.id,
            prompt: scene.description,
          ),
        );
      } else {
        debugPrint("SceneImageStage: ERROR - Workflow returned null job for scene ${scene.id}!");
      }
    } catch (e) {
      debugPrint("SceneImageStage: ERROR running workflow for scene ${scene.id}: $e");
      rethrow;
    }
  }
  debugPrint("SceneImageStage: Finished. project.images contains ${project.images.length} images.");
 }
}