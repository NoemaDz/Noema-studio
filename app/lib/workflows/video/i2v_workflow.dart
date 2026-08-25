import '../../core/providers/video_provider.dart';
import '../../core/workflow/workflow.dart';

import 'generate_video_step.dart';

class I2vWorkflow extends Workflow {
  I2vWorkflow(VideoProvider provider)
    : super(
        id: "i2v_workflow",
        name: "I2V Workflow",
        steps: [GenerateVideoStep(provider)],
      );
}
