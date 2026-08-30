import 'provider.dart';
import '../../models/job.dart';
import '../../models/asset.dart';

abstract class AsyncProvider extends Provider {
  Future<JobStatusUpdate> updateJobStatus(Job job);
  Future<Asset?> downloadAsset(String jobId);
  Future<void> cancelJob(String jobId);
}
