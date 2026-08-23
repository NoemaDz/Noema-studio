import '../models/scene.dart';

class PromptBuilderService {
  String build(Scene scene) {
    return '''
masterpiece,
best quality,
ultra detailed,
cinematic lighting,
8k,
highly detailed,

${scene.description}
''';
  }
}