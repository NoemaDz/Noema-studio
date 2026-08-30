import '../../core/noema_project.dart';
import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/job_manager.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';
import '../../models/character.dart';
import '../../core/contracts/execution_request.dart';
import '../../core/capabilities/capability.dart';

class GenerateCharacterImagesStep extends WorkflowStep<void> {
  final ImageProvider provider;

  GenerateCharacterImagesStep(this.provider);

  @override
  String get id => "character_images";

  @override
  String get name => "Generate Character Images";

  @override
  Future<void> execute(WorkflowContext context) async {
    final project = context.get<NoemaProject>("project")!;

    final Map<Character, String> pendingJobs = {};

    for (final character in project.characters) {
      if (character.prompt == null) continue;

      final request = ExecutionRequest(
        capability: CapabilityType.imageGeneration,
        input: character.prompt!,
        parameters: {},
      );

      final job = await provider.execute(request);

      job.metadata["title"] = "Generating Character: ${character.name}";

      final jobManager = context.get<JobManager>("jobManager")!;
      jobManager.add(job);
      project.jobIds.add(job.id);
      pendingJobs[character] = job.id;
    }

    // Wait for all character image jobs to complete
    final jobManager = context.get<JobManager>("jobManager")!;
    for (final entry in pendingJobs.entries) {
      final character = entry.key;
      final jobId = entry.value;

      await jobManager.waitForCompletion(jobId);
      final job = jobManager.find(jobId);

      if (job != null && job.status == JobStatus.completed) {
        final execResult = await provider.getResult(jobId);
        if (execResult.isSuccess && execResult.textOutput != null) {
          character.imagePath = execResult.textOutput!;
        }
      }
    }
  }
}
