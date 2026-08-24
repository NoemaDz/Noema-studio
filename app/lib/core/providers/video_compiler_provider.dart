import 'provider.dart';
import '../../models/job.dart';

class AudioVideoResource {
  final String imagePath;
  final List<String> audioPaths;
  final String? effect;

  AudioVideoResource({
    required this.imagePath,
    required this.audioPaths,
    this.effect,
  });
}

abstract class VideoCompilerProvider extends Provider {
  Future<Job> compileVideo(
    List<AudioVideoResource> resources,
    String outputPath, {
    Map<String, dynamic>? options,
  });
}
