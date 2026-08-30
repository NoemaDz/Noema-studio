import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../models/job.dart';
import '../../main.dart';

import '../../core/providers/proxy_image_provider.dart';

/// A premium character editor dialog with voice profile selection
/// and a "Generate Test Image" feature.
class CharacterEditorDialog extends StatefulWidget {
  final Character character;
  final VoidCallback? onSaved;

  const CharacterEditorDialog({
    super.key,
    required this.character,
    this.onSaved,
  });

  /// Opens the editor as a modal dialog.
  static Future<void> show(
    BuildContext context,
    Character character, {
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          CharacterEditorDialog(character: character, onSaved: onSaved),
    );
  }

  @override
  State<CharacterEditorDialog> createState() => _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends State<CharacterEditorDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _promptController;
  late String? _selectedVoice;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  bool _isGeneratingImage = false;
  String? _generatedImagePath;
  String? _generateError;

  // Voice presets matching EdgeTTS voices (id, label)
  static const List<(String, String)> _voiceOptions = [
    ('en-US-AriaNeural', '🎙️ Aria (Woman, English)'),
    ('en-US-ChristopherNeural', '🎙️ Christopher (Man, English)'),
    ('en-US-GuyNeural', '🎙️ Guy (Man, English)'),
    ('en-US-JennyNeural', '🎙️ Jenny (Woman, English)'),
    ('en-GB-SoniaNeural', '🎙️ Sonia (Woman, British)'),
    ('en-GB-RyanNeural', '🎙️ Ryan (Man, British)'),
    ('ar-SA-HamedNeural', '🎙️ Hamed (Man, Arabic)'),
    ('ar-SA-ZariyahNeural', '🎙️ Zariyah (Woman, Arabic)'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _descController = TextEditingController(text: widget.character.description);
    _promptController = TextEditingController(
      text: widget.character.prompt ?? '',
    );
    _selectedVoice = widget.character.voiceProfile;
    _generatedImagePath = widget.character.imagePath;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 4, end: 16).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _generateTestImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _generateError = 'Please enter a visual prompt first.');
      return;
    }
    setState(() {
      _isGeneratingImage = true;
      _generateError = null;
    });

    try {
      final provider = noema.bootstrap.pluginContext.providers.all
          .whereType<ProxyImageProvider>()
          .firstOrNull;
      if (provider == null) {
        setState(() => _generateError = 'Image provider not available.');
        return;
      }

      final job = await provider.submitJob(
        prompt,
        options: {'width': 512, 'height': 512},
      );
      noema.bootstrap.jobManager.add(job);

      // Poll until done (timeout 3min)
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(seconds: 2));
        await provider.updateJobStatus(job);
        if (job.status == JobStatus.completed ||
            job.status == JobStatus.failed) {
          break;
        }
      }

      await provider.updateJobStatus(job);
      if (job.status == JobStatus.completed && job.result != null) {
        setState(() {
          _generatedImagePath = job.result;
          widget.character.imagePath = job.result;
        });
      } else {
        setState(
          () => _generateError = job.error?.message ?? 'Image generation failed.',
        );
      }
    } catch (e) {
      setState(() => _generateError = e.toString());
    } finally {
      setState(() => _isGeneratingImage = false);
    }
  }

  void _save() {
    widget.character
      ..prompt = _promptController.text.trim().isNotEmpty
          ? _promptController.text.trim()
          : null
      ..voiceProfile = _selectedVoice;
    widget.onSaved?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.25),
                    cs.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.5),
                            blurRadius: _glowAnim.value,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, color: cs.primary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Character',
                          style: tt.titleLarge?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _nameController.text,
                          style: tt.bodySmall?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image preview + generate button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 140,
                            height: 160,
                            child: _isGeneratingImage
                                ? Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AnimatedBuilder(
                                          animation: _glowAnim,
                                          builder: (context2, child) => Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: cs.primary.withValues(
                                                alpha: 0.2,
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: cs.primary.withValues(
                                                    alpha: 0.5,
                                                  ),
                                                  blurRadius: _glowAnim.value,
                                                ),
                                              ],
                                            ),
                                            child:
                                                const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Generating...',
                                          style: tt.labelSmall?.copyWith(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _generatedImagePath != null &&
                                      File(_generatedImagePath!).existsSync()
                                ? Image.file(
                                    File(_generatedImagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Center(
                                      child: Icon(
                                        Icons.person,
                                        size: 60,
                                        color: cs.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visual Prompt',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _promptController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText:
                                      'e.g. A young woman with red hair, blue eyes, wearing a black jacket...',
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: cs.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: cs.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cs.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Generate test image button
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _isGeneratingImage
                                      ? null
                                      : _generateTestImage,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary.withValues(
                                      alpha: 0.85,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _isGeneratingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.auto_awesome,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isGeneratingImage
                                        ? 'Generating...'
                                        : '⚡ Generate Test Image',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              if (_generateError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _generateError!,
                                  style: tt.labelSmall?.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: cs.primary.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Description',
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Brief character description...',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Voice profile
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          color: cs.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Voice Profile',
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedVoice,
                          isExpanded: true,
                          dropdownColor: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                '🔇 Use App Default',
                                style: tt.bodyMedium?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            ..._voiceOptions.map(
                              (v) => DropdownMenuItem<String>(
                                // ignore: unnecessary_underscores
                                value: v.$1,
                                child: Text(v.$2),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedVoice = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cs.primary.withValues(alpha: 0.15)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text(
                      'Save Character',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
