import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/tts_provider.dart';
import '../../job_manager.dart';
import '../../../workflows/audio/audio_workflow.dart';
import '../../../models/generated_audio.dart';
import '../../../models/job.dart';
import '../../../models/scene.dart';
import '../../../models/asset.dart';
import '../../../models/asset_type.dart';

class SceneAudioStage extends PipelineStage {
  @override
  int get priority => 60;

  final WorkflowEngine engine;
  final TTSProvider provider;
  final JobManager jobManager;

  SceneAudioStage({
    required this.engine,
    required this.provider,
    required this.jobManager,
  });

  @override
  Future<void> run(NoemaProject project) async {
    project.audios.clear();
    for (final scene in project.story.scenes) {
      await runForScene(project, scene);
    }
  }

  @override
  Future<void> runForScene(NoemaProject project, Scene scene) async {
    // Generate Narration if present
    if (scene.narration != null && scene.narration!.isNotEmpty) {
      final workflow = AudioWorkflow(provider);
      final context = WorkflowContext();
      context.set("text", scene.narration!);

      final result = await engine.runWithContext(workflow, context);
      final job = result.get<Job>("audio")!;
      jobManager.add(job);
      project.jobIds.add(job.id);

      final audio = GeneratedAudio(
        sceneId: scene.id,
        characterName: "Narrator",
        jobId: job.id,
        text: scene.narration!,
      );
      await jobManager.waitForCompletion(job.id, token: cancellationToken);

      if (job.status == JobStatus.completed && job.result != null) {
        audio.asset = Asset(
          id: job.id,
          path: job.result!,
          type: AssetType.audio,
        );
      } else {
        throw Exception("Audio generation failed: ${job.result}");
      }
      project.audios.add(audio);
    }

    // Generate Dialogue Audio
    for (final dialogueLine in scene.dialogue) {
      if (dialogueLine.text.trim().isEmpty) continue;

      final workflow = AudioWorkflow(provider);
      final context = WorkflowContext();

      // Find the character's voice profile
      final character = project.characters.cast<dynamic>().firstWhere(
        (c) => c.name == dialogueLine.characterName,
        orElse: () => null,
      );

      context.set("text", dialogueLine.text);
      context.set("characterName", dialogueLine.characterName);
      
      if (character != null && character.voiceProfile != null) {
        context.set("voiceProfile", character.voiceProfile!);
      }

      final result = await engine.runWithContext(workflow, context);
      final job = result.get<Job>("audio")!;
      jobManager.add(job);
      project.jobIds.add(job.id);

      final audio = GeneratedAudio(
        sceneId: scene.id,
        characterName: dialogueLine.characterName,
        jobId: job.id,
        text: dialogueLine.text,
      );
      await jobManager.waitForCompletion(job.id, token: cancellationToken);

      if (job.status == JobStatus.completed && job.result != null) {
        audio.asset = Asset(
          id: job.id,
          path: job.result!,
          type: AssetType.audio,
        );
      } else {
        throw Exception("Audio generation failed: ${job.result}");
      }
      project.audios.add(audio);
    }

    // Fallback: If no narration and no dialogue, generate description
    if ((scene.narration == null || scene.narration!.isEmpty) &&
        scene.dialogue.isEmpty) {
      final workflow = AudioWorkflow(provider);
      final context = WorkflowContext();
      context.set("text", scene.description);

      final result = await engine.runWithContext(workflow, context);
      final job = result.get<Job>("audio")!;
      jobManager.add(job);
      project.jobIds.add(job.id);

      final audio = GeneratedAudio(
        sceneId: scene.id,
        characterName: "Narrator",
        jobId: job.id,
        text: scene.description,
      );
      await jobManager.waitForCompletion(job.id, token: cancellationToken);

      if (job.status == JobStatus.completed && job.result != null) {
        audio.asset = Asset(
          id: job.id,
          path: job.result!,
          type: AssetType.audio,
        );
      } else {
        throw Exception("Audio generation failed: ${job.result}");
      }
      project.audios.add(audio);
    }
  }
}
