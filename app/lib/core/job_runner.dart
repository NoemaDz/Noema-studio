import '../models/job.dart';
import 'providers/provider_registry.dart';
import 'providers/async_provider.dart';

class JobRunner {
  final ProviderRegistry registry;

  JobRunner(this.registry);

  Future<void> update(Job job) async {
    if (!registry.has(job.providerId)) {
      return;
    }

    final provider = registry.get(job.providerId);
    if (provider is AsyncProvider) {
      try {
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
      } catch (e) {
        // A network or transient error occurred. We leave the job in its current state
        // so the system will retry polling it again on the next tick.
      }
    }
  }
}
