import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../application/comfyui_runner_service.dart';
import 'live_progress_tracker.dart';

class GenerationPanel extends StatelessWidget {
  final TextEditingController ideaController;
  final bool isGenerating;
  final String statusText;
  final List<Job> jobs;
  final VoidCallback onGenerate;
  final VoidCallback onImportStory;

  const GenerationPanel({
    super.key,
    required this.ideaController,
    required this.isGenerating,
    required this.statusText,
    required this.jobs,
    required this.onGenerate,
    required this.onImportStory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                color: statusText.startsWith("Error") ? Colors.red : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
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
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: isGenerating 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.auto_awesome),
              label: Text(
                isGenerating ? "Generating..." : "Generate Video",
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: ComfyUIRunnerService.instance,
            builder: (context, _) {
              final status = ComfyUIRunnerService.instance.status;
              Color dotColor = Colors.grey;
              String text = "Offline";
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
