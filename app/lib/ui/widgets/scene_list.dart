import 'package:flutter/material.dart';

import '../../models/scene.dart';
import 'scene_details.dart';

class SceneList extends StatelessWidget {
  final List<Scene> scenes;

  const SceneList({
    super.key,
    required this.scenes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Scenes",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...scenes.map(
              (scene) => ListTile(
  leading: CircleAvatar(
    child: Text("${scene.id}"),
  ),
  title: Text(scene.description),
  subtitle: Text(scene.imagePrompt ?? ""),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Scene"),
        content: SizedBox(
          width: 600,
          child: SceneDetails(
            scene: scene,
          ),
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