import 'dart:async';

import '../models/job.dart';
import 'job_events.dart';
import 'job_runner.dart';
import 'job_manager.dart';

class JobMonitor {
  final JobRunner runner;
  final JobManager manager;
  final JobEvents events;

  Timer? _timer;
  bool _isPolling = false;
  bool _isRunning = false;

  final Duration timeoutDuration;

  JobMonitor(this.runner, this.manager, this.events, {this.timeoutDuration = const Duration(minutes: 10)});

  void start() {
    _isRunning = true;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isPolling) return;
      _isPolling = true;

      try {
        final activeJobs = manager.jobs.toList();
        for (final job in activeJobs) {
          if (!_isRunning) break; // Early exit if stopped mid-poll

          if (job.status == JobStatus.completed ||
              job.status == JobStatus.failed) {
            continue;
          }
          // Timeout check
          final now = DateTime.now();
          if (job.startedAt != null) {
            final duration = now.difference(job.startedAt!);
            if (duration > timeoutDuration) {
              manager.applyUpdate(
                job.id,
                JobStatusUpdate(
                  status: JobStatus.failed,
                  error: JobError(
                    code: 'TIMEOUT',
                    message: 'Job exceeded maximum execution time of ${timeoutDuration.inMinutes} minutes.',
                  ),
                ),
              );
              events.emit(manager.find(job.id)!); // Emit updated job
              // Also trigger a background cancel
              manager.cancelJob(job.id);
              continue;
            }
          } else {
            // Check queued timeout if it's stuck in queue forever (e.g. 30 mins)
            final queuedDuration = now.difference(job.createdAt);
            if (queuedDuration > const Duration(minutes: 30)) {
               manager.applyUpdate(
                job.id,
                JobStatusUpdate(
                  status: JobStatus.failed,
                  error: JobError(
                    code: 'QUEUED_TIMEOUT',
                    message: 'Job was stuck in queue for too long.',
                  ),
                ),
              );
              events.emit(manager.find(job.id)!);
              manager.cancelJob(job.id);
              continue;
            }
          }

          final update = await runner.update(job);

          if (update != null) {
            manager.applyUpdate(job.id, update);
            events.emit(manager.find(job.id)!);
          }
        }
      } finally {
        _isPolling = false;
      }
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _isPolling = false;
  }
}
