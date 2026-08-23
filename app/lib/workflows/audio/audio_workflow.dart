import '../../core/providers/tts_provider.dart';
import '../../core/workflow/workflow.dart';

import 'generate_audio_step.dart';

class AudioWorkflow extends Workflow {
  AudioWorkflow(TTSProvider provider)
      : super(
          id: "audio_workflow",
          name: "Audio Workflow",
          steps: [
            GenerateAudioStep(provider),
          ],
        );
}
