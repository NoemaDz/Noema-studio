import 'package:flutter/foundation.dart';
import '../core/noema_project.dart';
import '../core/providers/provider_registry.dart';
import '../core/providers/async_provider.dart';
import '../models/job.dart';
import '../core/job_events.dart';
import '../presentation/state/project_state.dart';
import '../../main.dart'; // To access noema global

class ProjectSynchronizer {
  final NoemaProject project;

  final ProviderRegistry registry;
  final ProjectState state;

  ProjectSynchronizer({
    required this.project,
    required this.registry,
    required this.state,
  });

  void attach(JobEvents events) {
    events.clear(); // Prevent duplicate listeners when regenerating
    events.subscribe((job) async {
      await synchronize(job);
    });

    // Initial sync for jobs that are already completed before the monitor starts
    final jobs = noema.bootstrap.jobManager.jobs.where(
      (j) => project.jobIds.contains(j.id),
    );
    for (final job in jobs) {
      if (job.status == JobStatus.completed || job.status == JobStatus.failed) {
        synchronize(job);
      }
    }
  }

  Future<void> synchronize(Job job) async {
    if (job.status == JobStatus.failed) {
      // If a job fails, we should update the UI to show the error
      state.refresh();
      return;
    }

    if (job.status == JobStatus.completed && job.type == "video_compile") {
      project.finalVideoPath = job.result;
      state.refresh();
      noema.saveProject(project);
      return;
    }

    if (job.status != JobStatus.completed) {
      return;
    }

    if (job.type == "audio") {
      project.updateAudioFromJob(job);
      state.refresh();
      noema.saveProject(project);
      return;
    }

    if (job.type == "image") {
      try {
        final provider = registry.get(job.providerId);
        if (provider is AsyncProvider) {
          final asset = await provider.downloadAsset(job.id);
          if (asset != null) {
            debugPrint(
              "ProjectSynchronizer: project.images contains ${project.images.length} images.",
            );
            bool found = false;
            for (final image in project.images) {
              debugPrint(
                "ProjectSynchronizer: Comparing image.jobId=${image.jobId} with job.id=${job.id}",
              );
              if (image.jobId == job.id) {
                image.asset = asset;
                state.refresh();
                noema.saveProject(project);
                debugPrint("ProjectSynchronizer: Assigned asset to image!");
                found = true;
                break;
              }
            }
            if (!found) {
              debugPrint(
                "ProjectSynchronizer: WARNING - No image found with jobId ${job.id}!",
              );
              debugPrint(
                "ProjectSynchronizer: Currently in project.images: ${project.images.map((e) => e.jobId).toList()}",
              );
            }
          }
        }
      } catch (e) {
        debugPrint("ProjectSynchronizer Error: $e");
      }
      return;
    }
  }
}
