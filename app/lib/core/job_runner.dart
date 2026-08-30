import '../models/job.dart';
import 'providers/provider_registry.dart';
import 'providers/async_provider.dart';

class JobRunner {
  final ProviderRegistry registry;
  final Map<String, int> _transientFailures = {};

  JobRunner(this.registry);

  Future<JobStatusUpdate?> update(Job job) async {
    if (!registry.has(job.providerId)) {
      return null;
    }

    final provider = registry.get(job.providerId);
    if (provider is AsyncProvider) {
      try {
        final update = await provider.updateJobStatus(job);
        
        // Enhance the update based on our generic logic (like setting progress correctly for terminal states)
        double? newProgress = update.progress;
        switch (update.status) {
          case JobStatus.completed:
            newProgress = 1.0;
            break;
          case JobStatus.queued:
            newProgress = 0.05;
            break;
          case JobStatus.failed:
          case JobStatus.cancelled:
            newProgress = 0;
            break;
          default:
            break;
        }

        // Clear transient failure count on success
        _transientFailures.remove(job.id);
        
        return JobStatusUpdate(
            status: update.status, 
            progress: newProgress, 
            result: update.result, 
            error: update.error
        );
      } catch (e) {
        final currentFailures = (_transientFailures[job.id] ?? 0) + 1;
        _transientFailures[job.id] = currentFailures;

        if (currentFailures >= 5) {
          _transientFailures.remove(job.id);
          return JobStatusUpdate(
              status: JobStatus.failed, 
              error: JobError(code: 'MAX_RETRIES_EXCEEDED', message: "Failed to update job status after 5 retries: $e")
          );
        }
        // A network or transient error occurred. Return null to indicate no state change, retry next tick.
        return null;
      }
    }
    return null;
  }
}
