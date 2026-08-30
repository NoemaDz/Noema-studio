import '../contracts/pipeline_stage.dart';
import '../../settings/platform_paths.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/video_compiler_provider.dart';
import '../../job_manager.dart';
import '../../../workflows/video/video_workflow.dart';
import '../../../models/job.dart';
import '../../cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class VideoCompilationStage extends PipelineStage {
  @override
  int get priority => 70;

  final WorkflowEngine engine;
  final VideoCompilerProvider provider;
  final JobManager jobManager;

  VideoCompilationStage({
    required this.engine,
    required this.provider,
    required this.jobManager,
  });

  @override
  Future<void> run(NoemaProject project) async {
    final resources = <AudioVideoResource>[];

    // Gather images/videos and audios for each scene
    for (final scene in project.story.scenes) {
      final video = project.videos.cast<dynamic>().firstWhere(
        (vid) => vid.sceneId == scene.id,
        orElse: () => null,
      );

      final image = project.images.cast<dynamic>().firstWhere(
        (img) => img.sceneId == scene.id,
        orElse: () => null,
      );

      final mediaPath = video?.asset?.path ?? image?.asset?.path;

      if (mediaPath == null) {
        throw Exception("Missing image/video for scene ${scene.id}");
      }

      final audios = project.audios
          .where((aud) => aud.sceneId == scene.id)
          .toList();

      // If no audios exist, we skip or handle silently? Let's just gather whatever we have.
      final validAudioPaths = audios
          .where((aud) => aud.asset?.path != null)
          .map((aud) => aud.asset!.path)
          .toList();

      final subtitleText = audios
          .map((aud) => aud.text)
          .where((text) => text.trim().isNotEmpty)
          .join(" ");

      resources.add(
        AudioVideoResource(
          imagePath: mediaPath,
          audioPaths: validAudioPaths,
          subtitleText: subtitleText.isNotEmpty ? subtitleText : null,
          effect: scene.cameraEffect,
        ),
      );
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
    jobManager.add(job);
    project.jobIds.add(job.id);

    try {
      await jobManager.waitForCompletion(job.id, token: cancellationToken);
    } on CancelledException {
      debugPrint(
        'VideoCompilationStage: Cancellation requested, killing job ${job.id} on provider.',
      );
      await provider.cancelJob(job.id);
      rethrow;
    }

    if (job.status == JobStatus.failed) {
      throw Exception("Video compilation failed: ${job.result}");
    }

    // finalVideoPath will be updated when the job completes, similar to how updateAudioFromJob works.
    project.finalVideoPath = job.result;
  }
}
