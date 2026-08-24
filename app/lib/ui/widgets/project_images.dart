import 'package:flutter/material.dart';

import '../../models/generated_image.dart';

class ProjectImages extends StatelessWidget {
  final List<GeneratedImage> images;

  const ProjectImages({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Generated Images",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ...images.map(
              (image) => ListTile(
                leading: const Icon(Icons.image),
                title: Text("Scene ${image.sceneId}"),
                subtitle: Text(image.prompt),
                trailing: image.asset == null
                    ? const Icon(Icons.hourglass_empty)
                    : const Icon(Icons.visibility),
                onTap: image.asset == null
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                              child: Image.network(
                                image.asset!.path,
                                fit: BoxFit.contain,
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
