import 'package:flutter/material.dart';
import '../../core/noema_project.dart';
import '../../models/scene.dart';
import 'glass_container.dart';

class SceneEditorView extends StatefulWidget {
  final NoemaProject project;
  final VoidCallback onContinue;

  const SceneEditorView({
    super.key,
    required this.project,
    required this.onContinue,
  });

  @override
  State<SceneEditorView> createState() => _SceneEditorViewState();
}

class _SceneEditorViewState extends State<SceneEditorView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review & Edit Scenes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'The AI has planned the story. You can manually edit the image and audio prompts for each scene before we start generating media.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.project.story.scenes.length,
            itemBuilder: (context, index) {
              final scene = widget.project.story.scenes[index];
              return _SceneEditorCard(scene: scene, onChanged: () {});
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: widget.onContinue,
                icon: const Icon(Icons.movie_creation),
                label: const Text('Confirm & Generate Media'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SceneEditorCard extends StatefulWidget {
  final Scene scene;
  final VoidCallback onChanged;

  const _SceneEditorCard({required this.scene, required this.onChanged});

  @override
  State<_SceneEditorCard> createState() => _SceneEditorCardState();
}

class _SceneEditorCardState extends State<_SceneEditorCard> {
  late TextEditingController _imagePromptController;
  late TextEditingController _audioNarrationController;

  @override
  void initState() {
    super.initState();
    _imagePromptController = TextEditingController(
      text: widget.scene.imagePrompt ?? widget.scene.description,
    );
    _audioNarrationController = TextEditingController(
      text: widget.scene.narration ?? '',
    );
  }

  @override
  void dispose() {
    _imagePromptController.dispose();
    _audioNarrationController.dispose();
    super.dispose();
  }

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
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: GlassContainer(
          blurRadius: 10,
          opacity: 0.1,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Scene ${widget.scene.id}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Original Description:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.scene.description,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imagePromptController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Image Prompt (Sent to ComfyUI)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.5),
                ),
                onChanged: (value) {
                  widget.scene.imagePrompt = value;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _audioNarrationController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Audio Narration (Sent to TTS)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.5),
                ),
                onChanged: (value) {
                  widget.scene.narration = value;
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
