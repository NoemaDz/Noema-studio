import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/noema_project.dart';
import '../../models/generated_image.dart';
import '../../models/generated_audio.dart';
import '../../models/generation_state.dart';
import 'package:shimmer/shimmer.dart';

class StoryboardViewWidget extends StatelessWidget {
  final NoemaProject project;

  const StoryboardViewWidget({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    if (project.story.scenes.isEmpty) {
      return const Center(child: Text("No scenes generated yet."));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: project.story.scenes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final scene = project.story.scenes[index];
        final image = _getImageForScene(scene.id);
        
        return Container(
          width: 250,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Header
              Expanded(
                flex: 3,
                child: image != null && image.asset != null
                    ? (image.asset!.path.startsWith("http")
                        ? Image.network(
                            image.asset!.path,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(image.asset!.path),
                            fit: BoxFit.cover,
                          ))
                    : scene.imageState == GenerationState.generating
                        ? Shimmer.fromColors(
                            baseColor: Colors.grey.shade800,
                            highlightColor: Colors.grey.shade600,
                            child: Container(
                              color: Colors.grey.shade800,
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: const Center(
                              child: Icon(Icons.image_search, color: Colors.white54, size: 32),
                            ),
                          ),
              ),
              // Text Content
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Scene ${index + 1}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                _getImageForScene(scene.id)?.asset != null ? Icons.image : Icons.hourglass_empty,
                                size: 14,
                                color: _getImageForScene(scene.id)?.asset != null ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _getAudioForScene(scene.id)?.asset != null ? Icons.audiotrack : Icons.hourglass_empty,
                                size: 14,
                                color: _getAudioForScene(scene.id)?.asset != null ? Colors.green : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scene.description,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (scene.dialogue.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text("💬 Dialogue:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                ...scene.dialogue.map((d) => Text("\${d.characterName}: \${d.text}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                              ],
                              if (scene.narration != null && scene.narration!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text("🎙️ Narration:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                                Text(scene.narration!, style: const TextStyle(fontSize: 12)),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (scene.cameraEffect != null) _buildTag(context, "🎥 ${scene.cameraEffect}"),
                                  if (scene.mood != null) _buildTag(context, "🎭 ${scene.mood}"),
                                  if (scene.colorGrading != null) _buildTag(context, "🎨 ${scene.colorGrading}"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }

  GeneratedImage? _getImageForScene(int sceneId) {
    try {
      return project.images.firstWhere((img) => img.sceneId == sceneId);
    } catch (_) {
      return null;
    }
  }

  GeneratedAudio? _getAudioForScene(int sceneId) {
    try {
      return project.audios.firstWhere((aud) => aud.sceneId == sceneId);
    } catch (_) {
      return null;
    }
  }
}
