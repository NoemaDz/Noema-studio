import 'provider.dart';
import '../../models/job.dart';

abstract class AsyncProvider extends Provider {
  /// Polls the external service to update the job status.
  Future<JobStatusUpdate> updateJobStatus(Job job);
}
