import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../main.dart'; // To access global `noema`
import '../../application/project_synchronizer.dart';
import '../../application/comfyui_runner_service.dart';
import '../../core/noema_project.dart';
import '../widgets/video_preview.dart';
import '../widgets/storyboard_view.dart';
import '../../models/story.dart' as import_story;
import '../../models/generation_state.dart';
import '../../core/cancellation_token.dart';
import '../widgets/generation_panel.dart';
import '../widgets/scene_editor_view.dart';
import '../widgets/glass_container.dart';
import '../widgets/character_list.dart';
import '../widgets/agent_panel.dart';
import 'settings_dialog.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _ideaController = TextEditingController();
  bool _isGenerating = false;
  String _statusText = "Ready";
  CancellationToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMockProject();
    });
    // Start ComfyUI silently in the background
    ComfyUIRunnerService.instance.start();
  }

  void _loadMockProject() {
    // Left empty for actual generation to happen instead of mocking.
    // If we wanted to load a previously saved project, we'd do it here.
  }

  @override
  void dispose() {
    ComfyUIRunnerService.instance.stop();
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _generateProject() async {
    if (_ideaController.text.trim().isEmpty) return;

    final settings = noema.bootstrap.appSettings;
    if (settings.activeLlmProvider == 'openai' &&
        settings.openAiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "OpenAI API Key is missing. Please add it in Settings.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusText = "Starting planning phase...";
    });

    try {
      final p = NoemaProject(
        id: const Uuid().v4(),
        idea: _ideaController.text,
        story: import_story.Story(title: "Generating...", scenes: []),
      );
      noema.bootstrap.projectState.setProject(p);

      await noema.generatePlanning(p);

      if (!mounted) return;
      setState(() {
        _statusText = "Planning complete. Please review scenes.";
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Error: $e";
        _isGenerating = false;
      });
    }
  }

  Future<void> _continueToProduction() async {
    final p = noema.bootstrap.projectState.project;
    if (p == null) return;

    final settings = noema.bootstrap.appSettings;
    if (settings.activeImageProvider == 'openai_image' &&
        settings.openAiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "OpenAI API Key is required for DALL-E. Please add it in Settings.",
          ),
        ),
      );
      return;
    }
    if (settings.activeTtsProvider == 'openai_tts' &&
        settings.openAiKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "OpenAI API Key is required for OpenAI TTS. Please add it in Settings.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusText = "Starting production phase...";
      _cancelToken = CancellationToken();
    });

    try {
      await noema.generateProduction(
        p,
        cancellationToken: _cancelToken,
        onUpdate: (status) {
          if (mounted) {
            setState(() {
              _statusText = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _statusText = "Pipeline completed.";
          _isGenerating = false;
          _cancelToken = null;
        });
      }
    } on CancelledException {
      if (mounted) {
        setState(() {
          _statusText = "Pipeline cancelled.";
          _isGenerating = false;
          _cancelToken = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = "Error: $e";
          _isGenerating = false;
          _cancelToken = null;
        });
      }
    }
  }

  void _cancelGeneration() {
    _cancelToken?.cancel();
    setState(() {
      _statusText = "Cancelling pipeline...";
    });
  }

  Future<void> _importStory() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _isGenerating = true;
          _statusText = "Reading document...";
        });

        final text = await noema.documentIngestionService.importDocument(
          files.first.path!,
        );

        if (!mounted) return;
        setState(() {
          _ideaController.text = text;
          _isGenerating = false;
          _statusText = "Document imported successfully.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Import Error: $e";
        _isGenerating = false;
      });
    }
  }

  void _newProject() {
    final p = NoemaProject(
      id: const Uuid().v4(),
      idea: "",
      story: import_story.Story(title: "New Project", scenes: []),
    );
    noema.bootstrap.projectState.setProject(p);
    setState(() {
      _ideaController.clear();
      _statusText = "New Project Created.";
    });
  }

  Future<void> _saveProject() async {
    final project = noema.bootstrap.projectState.project;
    if (project == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No project to save.")));
      return;
    }

    try {
      await noema.saveProject(project);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Project saved successfully.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
    }
  }

  Future<void> _loadProject() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      try {
        final project = await noema.openProject(files.first.path!);
        noema.bootstrap.projectState.setProject(project);

        final synchronizer = ProjectSynchronizer(
          project: project,
          registry: noema.bootstrap.providerRegistry,
          state: noema.bootstrap.projectState,
          jobManager: noema.bootstrap.jobManager,
          saveProject: noema.saveProject,
        );
        synchronizer.attach(noema.bootstrap.jobEvents);
        noema.bootstrap.jobMonitor.start();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading project: $e")));
      }
    }
  }

  void _openAdvancedMode() {
    final url = noema.bootstrap.appSettings.comfyUIUrl;
    if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    } else if (Platform.isWindows) {
      Process.run('start', [url], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.run('open', [url]);
    }
  }

  Widget _buildMenuBar(BuildContext context) {
    return MenuBar(
      style: MenuStyle(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
      ),
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _newProject,
              leadingIcon: const Icon(Icons.note_add_outlined, size: 18),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
              ),
              child: const Text('New Project'),
            ),
            MenuItemButton(
              onPressed: _loadProject,
              leadingIcon: const Icon(Icons.folder_open_outlined, size: 18),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ),
              child: const Text('Open Project...'),
            ),
            MenuItemButton(
              onPressed: _saveProject,
              leadingIcon: const Icon(Icons.save_outlined, size: 18),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
              ),
              child: const Text('Save Project As...'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const SettingsDialog(),
                );
              },
              leadingIcon: const Icon(Icons.settings_outlined, size: 18),
              child: const Text('Settings'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(Icons.exit_to_app, size: 18),
              child: const Text('Exit'),
            ),
          ],
          child: const Text(
            'File',
            softWrap: false,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _generateProject,
              leadingIcon: const Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: Colors.green,
              ),
              child: const Text('Generate / Run Pipeline', softWrap: false),
            ),
            MenuItemButton(
              onPressed: _importStory,
              leadingIcon: const Icon(Icons.upload_file_outlined, size: 18),
              child: const Text('Import Script...', softWrap: false),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(Icons.movie_creation_outlined, size: 18),
              child: const Text('Export Video...', softWrap: false),
            ),
          ],
          child: const Text(
            'Project',
            softWrap: false,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 18,
              ),
              child: const Text('Add Scene', softWrap: false),
            ),
            MenuItemButton(
              onPressed: () {},
              leadingIcon: const Icon(
                Icons.person_add_alt_1_outlined,
                size: 18,
              ),
              child: const Text('Add Character', softWrap: false),
            ),
          ],
          child: const Text(
            'Add',
            softWrap: false,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _openAdvancedMode,
              leadingIcon: const Icon(Icons.developer_board, size: 18),
              child: const Text(
                'Open Workflow Editor (Advanced Mode)',
                softWrap: false,
              ),
            ),
          ],
          child: const Text(
            'Tools',
            softWrap: false,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // 1. Menu Bar
          GlassContainer(
            width: double.infinity,
            blurRadius: 20,
            opacity: 0.1,
            border: const Border(
              bottom: BorderSide(color: Colors.white10, width: 1),
            ),
            child: _buildMenuBar(context),
          ),

          // 2. Main Workspace
          Expanded(
            child: ListenableBuilder(
              listenable: noema.bootstrap.projectState,
              builder: (context, _) {
                final project = noema.bootstrap.projectState.project;

                return Row(
                  children: [
                    // Left Sidebar: Controls & Progress
                    GenerationPanel(
                      ideaController: _ideaController,
                      isGenerating: _isGenerating,
                      statusText: _statusText,
                      pipelineStatus:
                          noema.bootstrap.projectState.pipelineStatus,
                      jobs: project != null
                          ? noema.bootstrap.jobManager.jobs
                                .where((j) => project.jobIds.contains(j.id))
                                .toList()
                          : [],
                      onGenerate: _generateProject,
                      onCancel: _cancelGeneration,
                      onImportStory: _importStory,
                    ),

                    // Right Workspace: Video & Storyboard
                    Expanded(
                      child: project?.projectState == GenerationState.reviewing
                          ? SceneEditorView(
                              project: project!,
                              onContinue: _continueToProduction,
                            )
                          : Column(
                              children: [
                                // Top: Video Player
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: VideoPreviewWidget(
                                      videoPath: project?.finalVideoPath,
                                    ),
                                  ),
                                ),

                                // Bottom: Storyboard
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.1),
                                      border: Border(
                                        top: BorderSide(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                      ),
                                    ),
                                    child: project != null
                                        ? StoryboardViewWidget(project: project)
                                        : const Center(
                                            child: Text(
                                              "Timeline empty. Generate a project to see scenes.",
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    // Right Sidebar: Characters Panel
                    if (project != null && project.characters.isNotEmpty)
                      GlassContainer(
                        width: 240,
                        color: Theme.of(context).colorScheme.surface,
                        opacity: 0.12,
                        border: const Border(
                          left: BorderSide(color: Colors.white10, width: 1.0),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: CharacterList(
                            characters: project.characters,
                            onCharacterUpdated: () => setState(() {}),
                          ),
                        ),
                      ),

                    // Agent Panel
                    const AgentPanel(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
