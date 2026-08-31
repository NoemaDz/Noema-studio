import 'dart:async';
import '../models/job.dart';
import 'providers/provider_registry.dart';
import 'cancellation_token.dart';

class JobManager {
  final ProviderRegistry? registry;
  final List<Job> _jobs = [];

  JobManager({this.registry});

  List<Job> get jobs => List.unmodifiable(_jobs);

  Job add(Job job) {
    _jobs.add(job);
    return job;
  }

  Job? find(String id) {
    try {
      return _jobs.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void applyUpdate(String id, JobStatusUpdate update) {
    final job = find(id);
    if (job == null) return;

    if (job.transitionTo(update.status)) {
      if (update.progress != null) {
        // Enforce monotonic progress: do not allow progress to decrease
        if (update.progress! >= job.progress) {
          job.progress = update.progress!;
        } else {
          print(
            "WARNING: Ignored progress regression for Job ${job.id}: ${job.progress} -> ${update.progress}",
          );
        }
      }
      if (update.result != null) job.result = update.result;
      if (update.error != null) job.error = update.error;
    } else {
      print(
        "WARNING: Illegal transition attempted for Job ${job.id} to ${update.status}",
      );
    }
  }

  void updateStatus(String id, JobStatus status) {
    final job = find(id);

    if (job != null) {
      if (!job.transitionTo(status)) {
        // Log illegal transition attempt
        // TODO: use structured logging later
        print(
          "WARNING: Illegal transition attempted for Job ${job.id} to $status",
        );
      }
    }
  }

  void updateProgress(String id, double progress) {
    final job = find(id);

    if (job != null) {
      job.progress = progress;
    }
  }

  void complete(String id, String result) {
    final job = find(id);

    if (job != null) {
      if (job.transitionTo(JobStatus.completed)) {
        job.progress = 1.0;
        job.result = result;
      }
    }
  }

  void fail(String id, JobError error) {
    final job = find(id);

    if (job != null) {
      if (job.transitionTo(JobStatus.failed)) {
        job.error = error;
      }
    }
  }

  Future<void> cancelJob(
    String id, {
    JobStatus finalStatus = JobStatus.cancelled,
    JobError? error,
  }) async {
    final job = find(id);
    if (job == null) return;

    // Only cancel if it's currently pending, queued, starting, running, or retrying.
    if (job.status == JobStatus.completed ||
        job.status == JobStatus.failed ||
        job.status == JobStatus.cancelled) {
      return;
    }

    if (job.transitionTo(JobStatus.cancelling)) {
      try {
        if (registry?.has(job.providerId) == true) {
          final provider = registry!.get(job.providerId);
          await provider.cancelJob(job.id);
        }
        if (job.transitionTo(finalStatus)) {
          if (error != null) job.error = error;
        }
      } catch (e) {
        job.transitionTo(JobStatus.failed);
        job.error = JobError(
          code: 'CANCEL_FAILED',
          message: 'Failed to cancel job: $e',
        );
      }
    }
  }

  void remove(String id) {
    _jobs.removeWhere((job) => job.id == id);
  }

  void clear() {
    _jobs.clear();
  }

  List<Job> byStatus(JobStatus status) {
    return _jobs.where((job) => job.status == status).toList();
  }

  bool contains(String id) {
    return find(id) != null;
  }

  /// Restores previously saved jobs into the manager.
  /// Skips jobs that are already tracked (by id).
  void restoreJobs(List<Job> jobs) {
    for (final job in jobs) {
      if (!contains(job.id)) {
        _jobs.add(job);
      }
    }
  }

  /// Returns a snapshot of all non-terminal jobs for persistence.
  /// These are the jobs that should be saved in the project file
  /// so they can be resumed if the app restarts.
  List<Job> snapshotActiveJobs() {
    return _jobs
        .where(
          (job) =>
              job.status != JobStatus.completed &&
              job.status != JobStatus.failed &&
              job.status != JobStatus.cancelled,
        )
        .toList();
  }

  Future<void> waitForCompletion(String id, {CancellationToken? token}) async {
    while (true) {
      if (token?.isCancelled == true) {
        throw CancelledException();
      }

      final job = find(id);
      if (job == null) {
        throw Exception("Job $id not found");
      }

      if (job.status == JobStatus.completed || job.status == JobStatus.failed) {
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
