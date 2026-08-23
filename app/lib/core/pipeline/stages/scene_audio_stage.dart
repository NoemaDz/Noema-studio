import '../contracts/pipeline_stage.dart';
import '../../noema_project.dart';
import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/tts_provider.dart';
import '../../../workflows/audio/audio_workflow.dart';
import '../../../models/generated_audio.dart';
import '../../../models/job.dart';

class SceneAudioStage implements PipelineStage {
  @override
  int get priority => 60;

  final WorkflowEngine engine;
  final TTSProvider provider;

  SceneAudioStage({
    required this.engine,
    required this.provider,
  });

  @override
  Future<void> run(NoemaProject project) async {
    project.audios.clear();

    for (final scene in project.story.scenes) {
      // Generate Narration if present
      if (scene.narration != null && scene.narration!.isNotEmpty) {
        final workflow = AudioWorkflow(provider);
        final context = WorkflowContext();
        context.set("text", scene.narration!);
        
        final result = await engine.runWithContext(workflow, context);
        final job = result.get<Job>("audio")!;
        project.jobs.add(job);
        
        project.audios.add(
          GeneratedAudio(
            sceneId: scene.id,
            characterName: "Narrator",
            jobId: job.id,
            text: scene.narration!,
          ),
        );
      }

      // Generate Dialogue Audio
      for (final dialogueLine in scene.dialogue) {
        if (dialogueLine.text.trim().isEmpty) continue;
        
        final workflow = AudioWorkflow(provider);
        final context = WorkflowContext();
        
        // TODO: Pass character name to TTS provider to pick voice profile
        context.set("text", dialogueLine.text);
        context.set("characterName", dialogueLine.characterName);
        
        final result = await engine.runWithContext(workflow, context);
        final job = result.get<Job>("audio")!;
        project.jobs.add(job);
        
        project.audios.add(
          GeneratedAudio(
            sceneId: scene.id,
            characterName: dialogueLine.characterName,
            jobId: job.id,
            text: dialogueLine.text,
          ),
        );
      }
      
      // Fallback: If no narration and no dialogue, generate description
      if ((scene.narration == null || scene.narration!.isEmpty) && scene.dialogue.isEmpty) {
        final workflow = AudioWorkflow(provider);
        final context = WorkflowContext();
        context.set("text", scene.description);
        
        final result = await engine.runWithContext(workflow, context);
        final job = result.get<Job>("audio")!;
        project.jobs.add(job);
        
        project.audios.add(
          GeneratedAudio(
            sceneId: scene.id,
            characterName: "Narrator",
            jobId: job.id,
            text: scene.description,
          ),
        );
      }
    }
  }
}
