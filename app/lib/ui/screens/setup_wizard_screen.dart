import 'package:flutter/material.dart';
import '../../application/comfyui_installer_service.dart';

class SetupWizardScreen extends StatefulWidget {
  final ComfyUIInstallerService installerService;
  final VoidCallback onComplete;

  const SetupWizardScreen({
    super.key, 
    required this.installerService,
    required this.onComplete,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  @override
  void initState() {
    super.initState();
    // Start installation automatically when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.installerService.isInstalled) {
        widget.installerService.install();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ListenableBuilder(
            listenable: widget.installerService,
            builder: (context, _) {
              final state = widget.installerService.state;
              final progress = widget.installerService.progress;
              final message = widget.installerService.statusMessage;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 24),
                  const Text(
                    "AI Engine Setup",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We are preparing your local AI environment. This involves downloading ComfyUI and required nodes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  if (state == InstallerState.error) ...[
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(message, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => widget.installerService.install(),
                      child: const Text("Retry Installation"),
                    ),
                  ] else if (state == InstallerState.completed) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text(message, style: const TextStyle(color: Colors.green), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: widget.onComplete,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Launch AI Studio"),
                    ),
                  ] else ...[
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                    Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
