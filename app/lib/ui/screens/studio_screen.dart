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
import '../widgets/character_list.dart';
import '../widgets/agent_panel.dart';
import 'settings_dialog.dart';
import '../../models/job.dart';

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

  bool? _isLeftPanelOpen;
  bool? _isRightPanelOpen;

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
    _activeSynchronizer?.dispose();
    noema.bootstrap.agentOrchestratorService.stopTask();
    noema.bootstrap.jobManager.clear();
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

    final currentProject = noema.bootstrap.projectState.project;
    final currentState = currentProject?.projectState;

    if (currentProject != null &&
        (currentState == GenerationState.reviewing ||
            currentState == GenerationState.stopped ||
            currentState == GenerationState.generating)) {
      _continueToProduction();
      return;
    }

    setState(() {
      _isGenerating = true;
      _statusText = "Starting planning phase...";
      _cancelToken = CancellationToken();
    });

    try {
      noema.bootstrap.jobManager.clear();
      _activeSynchronizer?.dispose();
      noema.bootstrap.agentOrchestratorService.stopTask();

      final p = NoemaProject(
        id: const Uuid().v4(),
        idea: _ideaController.text,
        story: import_story.Story(title: "Rendering Pipeline...", scenes: []),
      );
      noema.bootstrap.projectState.setProject(p);

      final synchronizer = ProjectSynchronizer(
        project: p,
        registry: noema.bootstrap.providerRegistry,
        state: noema.bootstrap.projectState,
        jobManager: noema.bootstrap.jobManager,
        saveProject: noema.saveProject,
      );
      _activeSynchronizer = synchronizer;
      synchronizer.attach(noema.bootstrap.jobEvents);

      await noema.generatePlanning(p, cancellationToken: _cancelToken);

      await noema.saveProject(p);

      if (!mounted) return;
      setState(() {
        _statusText = "Planning complete. Please review scenes.";
        _isGenerating = false;
        _cancelToken = null;
      });
    } on CancelledException {
      final p = noema.bootstrap.projectState.project;
      if (p != null) {
        p.projectState = GenerationState.stopped;
        await noema.saveProject(p);
      }
      if (mounted) {
        setState(() {
          _statusText = "Planning stopped.";
          _isGenerating = false;
          _cancelToken = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = "Error: $e";
        _isGenerating = false;
        _cancelToken = null;
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
      final p = noema.bootstrap.projectState.project;
      if (p != null) {
        p.projectState = GenerationState.stopped;
        await noema.saveProject(p);
      }
      if (mounted) {
        setState(() {
          _statusText = "Pipeline stopped.";
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

    noema.bootstrap.agentOrchestratorService.stopTask();

    final project = noema.bootstrap.projectState.project;
    if (project != null) {
      for (final job in noema.bootstrap.jobManager.jobs.toList()) {
        if (project.jobIds.contains(job.id)) {
          if (job.status != JobStatus.completed &&
              job.status != JobStatus.failed &&
              job.status != JobStatus.cancelled) {
            noema.bootstrap.jobManager.cancelJob(job.id);
          }
        }
      }
    }

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

  ProjectSynchronizer? _activeSynchronizer;

  void _newProject() {
    noema.bootstrap.jobManager.clear();
    _activeSynchronizer?.dispose();
    noema.bootstrap.agentOrchestratorService.stopTask();

    final p = NoemaProject(
      id: const Uuid().v4(),
      idea: "",
      story: import_story.Story(title: "New Project", scenes: []),
    );
    noema.bootstrap.projectState.setProject(p);

    final synchronizer = ProjectSynchronizer(
      project: p,
      registry: noema.bootstrap.providerRegistry,
      state: noema.bootstrap.projectState,
      jobManager: noema.bootstrap.jobManager,
      saveProject: noema.saveProject,
    );
    _activeSynchronizer = synchronizer;
    synchronizer.attach(noema.bootstrap.jobEvents);

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
        noema.bootstrap.jobManager.clear();
        _activeSynchronizer?.dispose();
        noema.bootstrap.agentOrchestratorService.stopTask();

        final project = await noema.openProject(files.first.path!);
        noema.bootstrap.projectState.setProject(project);

        final synchronizer = ProjectSynchronizer(
          project: project,
          registry: noema.bootstrap.providerRegistry,
          state: noema.bootstrap.projectState,
          jobManager: noema.bootstrap.jobManager,
          saveProject: noema.saveProject,
        );
        _activeSynchronizer = synchronizer;
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

  Widget _buildMenuBar(BuildContext context, bool leftOpen, bool rightOpen) {
    return Row(
      children: [
        Expanded(
          child: MenuBar(
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
                    leadingIcon: const Icon(
                      Icons.folder_open_outlined,
                      size: 18,
                    ),
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
                    child: const Text(
                      'Generate / Run Pipeline',
                      softWrap: false,
                    ),
                  ),
                  MenuItemButton(
                    onPressed: _importStory,
                    leadingIcon: const Icon(
                      Icons.upload_file_outlined,
                      size: 18,
                    ),
                    child: const Text('Import Script...', softWrap: false),
                  ),
                  const Divider(),
                  MenuItemButton(
                    onPressed: () {},
                    leadingIcon: const Icon(
                      Icons.movie_creation_outlined,
                      size: 18,
                    ),
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
                    child: const Text('Advanced Node Editor', softWrap: false),
                  ),
                ],
                child: const Text(
                  'Tools',
                  softWrap: false,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ], // End MenuBar children
          ), // End MenuBar
        ), // End Expanded
        IconButton(
          icon: Icon(leftOpen ? Icons.menu_open : Icons.menu),
          tooltip: 'Toggle Director Panel',
          onPressed: () => setState(() => _isLeftPanelOpen = !leftOpen),
        ),
        IconButton(
          icon: Icon(
            rightOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
          ),
          tooltip: 'Toggle AI Assistant',
          onPressed: () => setState(() => _isRightPanelOpen = !rightOpen),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRightPanel(NoemaProject? project) {
    final hasCharacters = project != null && project.characters.isNotEmpty;

    Widget content;
    if (!hasCharacters) {
      content = const AgentPanel();
    } else {
      content = DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'AI Assistant'),
                Tab(text: 'Characters'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const AgentPanel(),
                  CharacterList(
                    characters: project.characters,
                    onCharacterUpdated: () => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool leftOpen = _isLeftPanelOpen ?? (screenWidth >= 1280);
    bool rightOpen = _isRightPanelOpen ?? (screenWidth >= 1600);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // 1. Menu Bar
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: _buildMenuBar(context, leftOpen, rightOpen),
          ),

          // 2. Main Workspace
          Expanded(
            child: ListenableBuilder(
              listenable: noema.bootstrap.projectState,
              builder: (context, _) {
                final project = noema.bootstrap.projectState.project;

                final isReviewing =
                    project?.projectState == GenerationState.reviewing;

                return Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          // Left Sidebar: Controls & Progress
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: leftOpen ? 320 : 0,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 320,
                                child: GenerationPanel(
                                  ideaController: _ideaController,
                                  isGenerating: _isGenerating,
                                  statusText: _statusText,
                                  pipelineStatus: noema
                                      .bootstrap
                                      .projectState
                                      .pipelineStatus,
                                  jobs: project != null
                                      ? noema.bootstrap.jobManager.jobs
                                            .where(
                                              (j) =>
                                                  project.jobIds.contains(j.id),
                                            )
                                            .toList()
                                      : [],
                                  onGenerate: _generateProject,
                                  onCancel: _cancelGeneration,
                                  onImportStory: _importStory,
                                ),
                              ),
                            ),
                          ),

                          // Center Workspace: Video & Scene Editor
                          Expanded(
                            child: isReviewing
                                ? SceneEditorView(
                                    project: project!,
                                    onContinue: _continueToProduction,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: VideoPreviewWidget(
                                      videoPath: project?.finalVideoPath,
                                    ),
                                  ),
                          ),

                          // Right Sidebar: Agent & Characters
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: rightOpen ? 320 : 0,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 320,
                                child: _buildRightPanel(project),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Sidebar: Storyboard / Timeline
                    if (!isReviewing)
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
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
                              ? StoryboardViewWidget(
                                  project: project,
                                  onGenerateScenes: _isGenerating
                                      ? null
                                      : _generateProject,
                                )
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.movie_filter_outlined,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "Start a new project or open an existing project.",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _newProject,
                                            icon: const Icon(Icons.note_add),
                                            label: const Text("New Project"),
                                          ),
                                          const SizedBox(width: 16),
                                          OutlinedButton.icon(
                                            onPressed: _loadProject,
                                            icon: const Icon(Icons.folder_open),
                                            label: const Text("Open Project"),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
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
