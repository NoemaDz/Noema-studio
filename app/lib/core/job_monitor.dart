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

  JobMonitor(this.runner, this.manager, this.events);

  void start(List<Job> jobs) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      for (final job in jobs) {
        if (job.status == JobStatus.completed ||
            job.status == JobStatus.failed) {
          continue;
        }
        await runner.update(job);

        manager.updateStatus(job.id, job.status);

        manager.updateProgress(job.id, job.progress);

        events.emit(job);
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
