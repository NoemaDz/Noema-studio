import '../../core/providers/video_compiler_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';

class CompileVideoStep extends WorkflowStep<Job> {
  final VideoCompilerProvider provider;

  CompileVideoStep(this.provider);

  @override
  String get id => "video_compile";

  @override
  String get name => "Compile Video";

  @override
  Future<Job> execute(WorkflowContext context) async {
    final resources = context.get<List<AudioVideoResource>>("resources");
    final outputPath = context.get<String>("outputPath");
    final options = context.get<Map<String, dynamic>>("options") ?? {};

    if (resources == null || outputPath == null) {
      throw Exception("Missing resources or outputPath for video compilation");
    }

    final job = await provider.compileVideo(resources, outputPath, options: options);

    return job;
  }
}
