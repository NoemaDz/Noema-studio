import 'package:flutter/material.dart';

import '../../models/character.dart';

class CharacterDetails extends StatelessWidget {
  final Character character;

  const CharacterDetails({
    super.key,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              character.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            Text(character.description),

            if (character.prompt != null) ...[
              const SizedBox(height: 16),
              const Text(
                "Prompt",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(character.prompt!),
            ],

            if (character.imagePath != null) ...[
              const SizedBox(height: 16),
              const Text(
                "Image",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(character.imagePath!),
            ],
          ],
        ),
      ),
    );
  }
}