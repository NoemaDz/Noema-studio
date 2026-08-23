import '../models/job.dart';
import 'providers/image_provider.dart';

class JobRunner {
  final ImageProvider provider;

  JobRunner(this.provider);

  Future<void> update(Job job) async {
    final status = await provider.getJobStatus(job.id);

    job.status = status;

    switch (status) {
      case JobStatus.completed:
        job.progress = 1.0;
        break;

      case JobStatus.running:
        if (job.progress < 0.9) {
          job.progress += 0.1;
        }
        break;

      case JobStatus.queued:
        job.progress = 0.05;
        break;

      case JobStatus.failed:
        job.progress = 0;
        break;

      case JobStatus.pending:
        break;
    }
  }
}