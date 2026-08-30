import '../../core/providers/tts_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';

import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';

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
    final voiceProfile = context.get<String>("voiceProfile");

    if (text == null) {
      throw Exception("Missing text for audio generation");
    }

    final request = ExecutionRequest(
      capability: CapabilityType.tts,
      input: text,
      parameters: {if (voiceProfile != null) 'voiceProfile': voiceProfile},
    );

    final job = await provider.execute(request);
    job.metadata["text"] = text;

    return job;
  }
}
