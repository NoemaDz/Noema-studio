import 'async_provider.dart';

import '../../models/job.dart';

abstract class ImageProvider extends AsyncProvider {
  Future<Job> submitJob(String prompt, {Map<String, dynamic>? options});
}
