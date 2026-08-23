import 'package:flutter/material.dart';

import '../../models/scene.dart';

class SceneDetails extends StatelessWidget {
  final Scene scene;

  const SceneDetails({
    super.key,
    required this.scene,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
  child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Scene ${scene.id}",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 12),

            Text(scene.description),

            if (scene.imagePrompt != null) ...[
              const SizedBox(height: 16),
              const Text(
                "Image Prompt",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(scene.imagePrompt!),
            ],

            if (scene.imagePath != null) ...[
              const SizedBox(height: 16),
              const Text(
                "Image",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(scene.imagePath!),
            ],
          ],
        ),
      ),
          ),
    );
  }
}