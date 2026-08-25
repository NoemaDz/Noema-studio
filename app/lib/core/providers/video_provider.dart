import 'async_provider.dart';

import '../../models/job.dart';

abstract class VideoProvider extends AsyncProvider {
  Future<Job> submitJob(
    String prompt,
    String imagePath, {
    Map<String, dynamic>? options,
  });
}
