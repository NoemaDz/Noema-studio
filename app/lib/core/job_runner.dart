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
        // We will no longer artificially increment progress. 
        // In the future, this should fetch real progress from the provider.
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
