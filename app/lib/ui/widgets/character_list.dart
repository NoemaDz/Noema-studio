import 'package:flutter/material.dart';

import '../../models/character.dart';
import 'character_details.dart';

class CharacterList extends StatelessWidget {
  final List<Character> characters;

  const CharacterList({super.key, required this.characters});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Characters",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...characters.map(
              (character) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(character.name),
                subtitle: Text(character.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Character"),
                      content: SizedBox(
                        width: 500,
                        child: CharacterDetails(character: character),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
