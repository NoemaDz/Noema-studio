import 'provider.dart';
import '../../models/job.dart';
import '../../models/asset.dart';

abstract class AsyncProvider extends Provider {
  Future<JobStatus> getJobStatus(String jobId);
  Future<Asset?> downloadAsset(String jobId);
  Future<void> cancelJob(String jobId);
}
