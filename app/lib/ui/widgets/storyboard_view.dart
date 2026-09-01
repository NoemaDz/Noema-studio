import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/noema_project.dart';
import '../../models/generated_image.dart';
import '../../models/generated_audio.dart';
import '../../models/generation_state.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/scene.dart';
import 'glass_container.dart';

class StoryboardViewWidget extends StatelessWidget {
  final NoemaProject project;

  const StoryboardViewWidget({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    if (project.story.scenes.isEmpty) {
      return const Center(child: Text("No scenes generated yet."));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: project.story.scenes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final scene = project.story.scenes[index];
        final image = _getImageForScene(scene.id);

        return _StoryboardCard(
          scene: scene,
          index: index,
          image: image,
          audio: _getAudioForScene(scene.id),
        );
      },
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

class _StoryboardCard extends StatefulWidget {
  final Scene scene;
  final int index;
  final GeneratedImage? image;
  final GeneratedAudio? audio;

  const _StoryboardCard({
    required this.scene,
    required this.index,
    required this.image,
    required this.audio,
  });

  @override
  State<_StoryboardCard> createState() => _StoryboardCardState();
}

class _StoryboardCardState extends State<_StoryboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.02 : 1.0,
          _isHovered ? 1.02 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: GlassContainer(
          blurRadius: 12,
          opacity: 0.15,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Header
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: widget.image != null && widget.image!.artifact != null
                      ? (widget.image!.artifact!.path.startsWith("http")
                            ? Image.network(
                                widget.image!.artifact!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(widget.image!.artifact!.path),
                                fit: BoxFit.cover,
                              ))
                      : widget.scene.imageState == GenerationState.generating
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade800,
                          highlightColor: Colors.grey.shade600,
                          child: Container(color: Colors.grey.shade800),
                        )
                      : Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: Icon(
                              Icons.image_search,
                              color: Colors.white54,
                              size: 32,
                            ),
                          ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Scene ${widget.index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                widget.image?.artifact != null
                                    ? Icons.image
                                    : Icons.hourglass_empty,
                                size: 14,
                                color: widget.image?.artifact != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                widget.audio?.artifact != null
                                    ? Icons.audiotrack
                                    : Icons.hourglass_empty,
                                size: 14,
                                color: widget.audio?.artifact != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.scene.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              if (widget.scene.dialogue.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "💬 Dialogue:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                ...widget.scene.dialogue.map(
                                  (d) => Text(
                                    "${d.characterName}: ${d.text}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              if (widget.scene.narration != null &&
                                  widget.scene.narration!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "🎙️ Narration:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                                Text(
                                  widget.scene.narration!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (widget.scene.cameraEffect != null)
                                    _buildTag(
                                      context,
                                      "🎥 ${widget.scene.cameraEffect}",
                                    ),
                                  if (widget.scene.mood != null)
                                    _buildTag(
                                      context,
                                      "🎭 ${widget.scene.mood}",
                                    ),
                                  if (widget.scene.colorGrading != null)
                                    _buildTag(
                                      context,
                                      "🎨 ${widget.scene.colorGrading}",
                                    ),
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
        ),
      ),
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
}
