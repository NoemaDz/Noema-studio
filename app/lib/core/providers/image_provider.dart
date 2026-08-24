import 'provider.dart';

import '../../models/job.dart';
import '../../models/asset.dart';

abstract class ImageProvider extends Provider {
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options});

  Future<JobStatus> getJobStatus(String jobId);

  Future<Asset?> downloadAsset(String jobId);

  Future<void> cancelJob(String jobId);
}
