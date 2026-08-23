import '../../core/providers/video_compiler_provider.dart';
import '../../core/workflow/workflow.dart';

import 'compile_video_step.dart';

class VideoCompilationWorkflow extends Workflow {
  VideoCompilationWorkflow(VideoCompilerProvider provider)
      : super(
          id: "video_compilation_workflow",
          name: "Video Compilation Workflow",
          steps: [
            CompileVideoStep(provider),
          ],
        );
}
