import 'package:flutter/foundation.dart';
import '../core/noema_project.dart';
import '../core/providers/provider_registry.dart';
import '../core/providers/async_provider.dart';
import '../models/job.dart';
import '../core/job_events.dart';
import '../presentation/state/project_state.dart';
import '../core/job_manager.dart';
import 'dart:async';

class ProjectSynchronizer {
  final NoemaProject project;

  final ProviderRegistry registry;
  final ProjectState state;
  final JobManager jobManager;
  final void Function(NoemaProject) saveProject;

  ProjectSynchronizer({
    required this.project,
    required this.registry,
    required this.state,
    required this.jobManager,
    required this.saveProject,
  });

  StreamSubscription? _subscription;

  Future<void> attach(JobEvents events) async {
    _subscription?.cancel();

    // Use asyncMap to process one event at a time sequentially
    _subscription = events.stream
        .asyncMap((job) async {
          await synchronize(job);
          return job;
        })
        .listen((_) {});

    // Initial sync for jobs that are already completed before the monitor starts
    final jobs = jobManager.jobs.where((j) => project.jobIds.contains(j.id));
    for (final job in jobs) {
      if (job.status == JobStatus.completed || job.status == JobStatus.failed) {
        await synchronize(job);
      }
    }
  }

  Future<void> synchronize(Job job) async {
    // Always update the savedJobs snapshot before saving
    _updateSavedJobs();

    if (job.status == JobStatus.failed) {
      // If a job fails, we should update the UI to show the error
      state.refresh();
      saveProject(project);
      return;
    }

    if (job.status == JobStatus.completed && job.type == "video_compile") {
      project.finalVideoPath = job.result;
      state.refresh();
      saveProject(project);
      return;
    }

    if (job.status != JobStatus.completed) {
      return;
    }

    if (job.type == "audio") {
      project.updateAudioFromJob(job);
      state.refresh();
      saveProject(project);
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
                saveProject(project);
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

    if (job.type == "video") {
      try {
        final provider = registry.get(job.providerId);
        if (provider is AsyncProvider) {
          final asset = await provider.downloadAsset(job.id);
          if (asset != null) {
            bool found = false;
            for (final video in project.videos) {
              if (video.jobId == job.id) {
                video.asset = asset;
                state.refresh();
                saveProject(project);
                found = true;
                break;
              }
            }
            if (!found) {
              debugPrint(
                "ProjectSynchronizer: WARNING - No video found with jobId ${job.id}!",
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

  /// Snapshots currently active (non-terminal) jobs into the project
  /// so they survive app restarts.
  void _updateSavedJobs() {
    project.savedJobs
      ..clear()
      ..addAll(jobManager.snapshotActiveJobs());
  }
}
