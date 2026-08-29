import '../models/job.dart';
import 'providers/provider_registry.dart';
import 'providers/async_provider.dart';

class JobRunner {
  final ProviderRegistry registry;
  final Map<String, int> _transientFailures = {};

  JobRunner(this.registry);

  Future<void> update(Job job) async {
    if (!registry.has(job.providerId)) {
      return;
    }

    final provider = registry.get(job.providerId);
    if (provider is AsyncProvider) {
      try {
        await provider.updateJobStatus(job);

        switch (job.status) {
          case JobStatus.completed:
            job.progress = 1.0;
            break;

          case JobStatus.running:
          case JobStatus.starting:
          case JobStatus.retrying:
          case JobStatus.cancelling:
            // We will no longer artificially increment progress.
            // In the future, this should fetch real progress from the provider.
            break;

          case JobStatus.queued:
            job.progress = 0.05;
            break;

          case JobStatus.failed:
          case JobStatus.cancelled:
            job.progress = 0;
            break;

          case JobStatus.pending:
            break;
        }
        // Clear transient failure count on success
        _transientFailures.remove(job.id);
      } catch (e) {
        final currentFailures = (_transientFailures[job.id] ?? 0) + 1;
        _transientFailures[job.id] = currentFailures;
        
        if (currentFailures >= 5) {
          job.transitionTo(JobStatus.failed);
          job.result = "Failed to update job status after 5 retries: $e";
          _transientFailures.remove(job.id);
        }
        // A network or transient error occurred. We leave the job in its current state
        // so the system will retry polling it again on the next tick.
      }
    }
  }
}
