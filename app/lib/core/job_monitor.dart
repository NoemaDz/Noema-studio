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

  JobMonitor(this.runner, this.manager, this.events);

  void start() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isPolling) return;
      _isPolling = true;

      try {
        final activeJobs = manager.jobs.toList();
        for (final job in activeJobs) {
          if (job.status == JobStatus.completed ||
              job.status == JobStatus.failed) {
            continue;
          }
          await runner.update(job);

          manager.updateStatus(job.id, job.status);
          manager.updateProgress(job.id, job.progress);

          events.emit(job);
        }
      } finally {
        _isPolling = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
