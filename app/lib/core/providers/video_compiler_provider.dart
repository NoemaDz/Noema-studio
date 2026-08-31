import 'async_provider.dart';

class AudioVideoResource {
  final String imagePath;
  final List<String> audioPaths;
  final String? subtitleText;
  final String? effect;

  AudioVideoResource({
    required this.imagePath,
    required this.audioPaths,
    this.subtitleText,
    this.effect,
  });
}

abstract class VideoCompilerProvider extends AsyncProvider {}
