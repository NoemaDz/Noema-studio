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

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'audioPaths': audioPaths,
    'subtitleText': subtitleText,
    'effect': effect,
  };

  factory AudioVideoResource.fromJson(Map<String, dynamic> json) {
    return AudioVideoResource(
      imagePath: json['imagePath'] as String,
      audioPaths: (json['audioPaths'] as List<dynamic>).cast<String>(),
      subtitleText: json['subtitleText'] as String?,
      effect: json['effect'] as String?,
    );
  }
}

abstract class VideoCompilerProvider extends AsyncProvider {}
