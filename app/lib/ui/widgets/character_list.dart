import 'package:flutter/material.dart';

import '../../models/character.dart';
import 'character_editor_dialog.dart';

class CharacterList extends StatelessWidget {
  final List<Character> characters;
  final VoidCallback? onCharacterUpdated;

  const CharacterList({
    super.key,
    required this.characters,
    this.onCharacterUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_alt, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Characters",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (characters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No characters yet. The Director Agent will create them from your story.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...characters.map(
                (character) => _CharacterTile(
                  character: character,
                  onUpdated: onCharacterUpdated,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  final Character character;
  final VoidCallback? onUpdated;

  const _CharacterTile({required this.character, this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = character.imagePath != null;
    final hasVoice = character.voiceProfile != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => CharacterEditorDialog.show(
            context,
            character,
            onSaved: onUpdated,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    hasImage ? Icons.image : Icons.person,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        character.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Indicators
                if (hasVoice)
                  Tooltip(
                    message: 'Voice: ${character.voiceProfile}',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.record_voice_over,
                        size: 14,
                        color: cs.secondary,
                      ),
                    ),
                  ),
                if (hasImage)
                  Tooltip(
                    message: 'Has test image',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.image_outlined,
                        size: 14,
                        color: cs.secondary,
                      ),
                    ),
                  ),
                Icon(Icons.edit_outlined, size: 16, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
