import '../contracts/pipeline_stage.dart';
import '../../settings/platform_paths.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/video_compiler_provider.dart';
import '../../../workflows/video/video_workflow.dart';
import '../../../models/job.dart';
import 'package:path/path.dart' as p;

class VideoCompilationStage extends PipelineStage {
  @override
  int get priority => 70;

  final WorkflowEngine engine;
  final VideoCompilerProvider provider;

  VideoCompilationStage({required this.engine, required this.provider});

  @override
  Future<void> run(NoemaProject project) async {
    final resources = <AudioVideoResource>[];

    // Gather images and audios for each scene
    for (final scene in project.story.scenes) {
      final image = project.images.firstWhere(
        (img) => img.sceneId == scene.id,
        orElse: () => throw Exception("Missing image for scene ${scene.id}"),
      );

      final audios = project.audios
          .where((aud) => aud.sceneId == scene.id)
          .toList();

      // If no audios exist, we skip or handle silently? Let's just gather whatever we have.
      final validAudioPaths = audios
          .where((aud) => aud.asset?.path != null)
          .map((aud) => aud.asset!.path)
          .toList();

      if (image.asset?.path != null) {
        resources.add(
          AudioVideoResource(
            imagePath: image.asset!.path,
            audioPaths: validAudioPaths,
            effect: scene.cameraEffect,
          ),
        );
      } else {
        // If assets aren't populated yet, we cannot compile.
        // Wait for jobs to finish in real execution.
      }
    }

    if (resources.isEmpty) {
      return; // Nothing to compile
    }

    final workflow = VideoCompilationWorkflow(provider);
    final context = WorkflowContext();

    await PlatformPaths.instance.init();
    final outputPath = p.join(
      project.settings['projectDirectory'] ??
          PlatformPaths.instance.projectsDirectory,
      "final_video_${DateTime.now().millisecondsSinceEpoch}.mp4",
    );

    context.set("resources", resources);
    context.set("outputPath", outputPath);
    context.set("options", project.settings);

    final result = await engine.runWithContext(workflow, context);

    final job = result.get<Job>("video_compile")!;
    project.jobs.add(job);

    // finalVideoPath will be updated when the job completes, similar to how updateAudioFromJob works.
    project.finalVideoPath = outputPath;
  }
}
