import '../models/character.dart';
import '../models/style.dart';

class ScenePromptBuilder {
  String build({
    required String scene,
    required List<Character> characters,
    required Style style,
  }) {
    final buffer = StringBuffer();

    // Style
    buffer.writeln("# STYLE");
    buffer.writeln(style.positivePrompt);
    buffer.writeln();

    // Characters
    buffer.writeln("# CHARACTERS");

    for (final character in characters) {
      buffer.writeln("Name: ${character.name}");
      buffer.writeln(character.description);

      if (character.prompt != null) {
        buffer.writeln("Prompt:");
        buffer.writeln(character.prompt);
      }

      if (character.imagePath != null) {
        buffer.writeln("Reference:");
        buffer.writeln(character.imagePath);
      }

      buffer.writeln();
    }

    // Scene
    buffer.writeln("# SCENE");
    buffer.writeln(scene);

    return buffer.toString();
  }
}
