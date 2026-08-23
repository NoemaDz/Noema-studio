import '../../core/providers/tts_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';

class GenerateAudioStep extends WorkflowStep<Job> {
  final TTSProvider provider;

  GenerateAudioStep(this.provider);

  @override
  String get id => "audio";

  @override
  String get name => "Generate Audio";

  @override
  Future<Job> execute(WorkflowContext context) async {
    final text = context.get<String>("text");

    if (text == null) {
      throw Exception("Missing text for audio generation");
    }

    final job = await provider.generateAudio(text);

    job.metadata["text"] = text;

    return job;
  }
}
