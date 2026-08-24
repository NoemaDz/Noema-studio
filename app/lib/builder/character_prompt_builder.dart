import '../models/character.dart';
import '../models/style.dart';

class CharacterPromptBuilder {
  String build({required Character character, required Style style}) {
    return """
${character.description}

${style.positivePrompt}
""";
  }
}
