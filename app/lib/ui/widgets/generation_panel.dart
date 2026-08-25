import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../application/comfyui_runner_service.dart';
import 'live_progress_tracker.dart';
import 'glass_container.dart';
import '../../main.dart';

class GenerationPanel extends StatelessWidget {
  final TextEditingController ideaController;
  final bool isGenerating;
  final String statusText;
  final String pipelineStatus;
  final List<Job> jobs;
  final VoidCallback onGenerate;
  final VoidCallback onImportStory;

  const GenerationPanel({
    super.key,
    required this.ideaController,
    required this.isGenerating,
    required this.statusText,
    required this.pipelineStatus,
    required this.jobs,
    required this.onGenerate,
    required this.onImportStory,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: 320,
      color: Theme.of(context).colorScheme.surface,
      opacity: 0.15,
      border: const Border(
        right: BorderSide(color: Colors.white10, width: 1.0),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    "Director Agent",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.file_upload, size: 20),
                tooltip: "Import Story (PDF, TXT, DOCX)",
                onPressed: isGenerating ? null : onImportStory,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: ideaController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: "Describe the video you want to generate...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              enabled: !isGenerating,
            ),
          ),
          const SizedBox(height: 24),
          if (isGenerating) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (statusText.isNotEmpty && statusText != "Ready") ...[
            Text(
              statusText,
              style: TextStyle(
                color: statusText.startsWith("Error")
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (pipelineStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pipelineStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (jobs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: LiveProgressTracker(jobs: jobs),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _AnimatedGenerateButton(
            isGenerating: isGenerating,
            onGenerate: onGenerate,
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: Listenable.merge([
              ComfyUIRunnerService.instance,
              noema.bootstrap.appSettings,
            ]),
            builder: (context, _) {
              final activeProvider =
                  noema.bootstrap.appSettings.activeImageProvider;
              Color dotColor = Colors.grey;
              String text = "Offline";

              if (activeProvider == 'openai_image') {
                final hasKey = noema.bootstrap.appSettings.openAiKey
                    .trim()
                    .isNotEmpty;
                if (hasKey) {
                  dotColor = Colors.green;
                  text = "Cloud Engine Ready";
                } else {
                  dotColor = Colors.red;
                  text = "Cloud API Key Missing";
                }
              } else {
                final status = ComfyUIRunnerService.instance.status;
                switch (status) {
                  case EngineStatus.offline:
                    dotColor = Colors.grey;
                    text = "Engine Offline";
                    break;
                  case EngineStatus.starting:
                    dotColor = Colors.amber;
                    text = "Starting Engine...";
                    break;
                  case EngineStatus.ready:
                    dotColor = Colors.green;
                    text = "Engine Ready";
                    break;
                  case EngineStatus.error:
                    dotColor = Colors.red;
                    text = "Engine Error";
                    break;
                }
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedGenerateButton extends StatefulWidget {
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _AnimatedGenerateButton({
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  State<_AnimatedGenerateButton> createState() =>
      _AnimatedGenerateButtonState();
}

class _AnimatedGenerateButtonState extends State<_AnimatedGenerateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _glowAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isGenerating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedGenerateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGenerating != oldWidget.isGenerating) {
      if (widget.isGenerating) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.animateTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isGenerating
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: _glowAnimation.value / 2,
                    ),
                  ]
                : null,
          ),
          child: FilledButton.icon(
            onPressed: widget.isGenerating ? null : widget.onGenerate,
            icon: widget.isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              widget.isGenerating ? "Generating..." : "Generate Video",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}
