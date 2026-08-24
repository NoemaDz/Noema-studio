import '../../core/noema_project.dart';
import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/job_manager.dart';
import '../../core/workflow/workflow_step.dart';
import '../../models/job.dart';
import '../../models/character.dart';

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

      final job = await provider.submitJob(character.prompt!);

      job.metadata["title"] = "Generating Character: ${character.name}";

      final jobManager = context.get<JobManager>("jobManager")!;
      jobManager.add(job);
      project.jobIds.add(job.id);
      pendingJobs[character] = job.id;
    }

    // Wait for all character image jobs to complete
    for (final entry in pendingJobs.entries) {
      final character = entry.key;
      final jobId = entry.value;

      bool isDone = false;
      while (!isDone) {
        final status = await provider.getJobStatus(jobId);
        if (status == JobStatus.completed || status == JobStatus.failed) {
          isDone = true;
          if (status == JobStatus.completed) {
            final asset = await provider.downloadAsset(jobId);
            if (asset != null) {
              character.imagePath = asset.path;
            }
          }
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }
}
