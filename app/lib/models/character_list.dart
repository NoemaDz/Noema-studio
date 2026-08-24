import 'character.dart';

class CharacterList {
  final List<Character> characters;

  CharacterList({required this.characters});

  factory CharacterList.fromJson(Map<String, dynamic> json) {
    final charsList = json["characters"] as List?;
    return CharacterList(
      characters: charsList != null
          ? charsList
                .map((e) => Character.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}
