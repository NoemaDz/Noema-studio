import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart'; // To access global `noema`
import '../../application/project_synchronizer.dart';
import '../../application/comfyui_runner_service.dart';
import '../../core/noema_project.dart';
import '../widgets/video_preview.dart';
import '../widgets/storyboard_view.dart';
import '../../models/story.dart' as import_story;
import '../widgets/generation_panel.dart';
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

    setState(() {
      _isGenerating = true;
      _statusText = "Starting pipeline...";
    });

    try {
      final p = NoemaProject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        idea: _ideaController.text,
        story: import_story.Story(title: "Generating...", scenes: []),
      );
      noema.bootstrap.projectState.setProject(p);
      
      final synchronizer = ProjectSynchronizer(
        project: p,
        provider: noema.bootstrap.imageProvider,
        state: noema.bootstrap.projectState,
      );
      synchronizer.attach(noema.bootstrap.jobEvents);
      noema.bootstrap.jobMonitor.start(p.jobs);

      await noema.generateProject(p);

      setState(() {
        _statusText = "Pipeline started. Processing in background...";
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _statusText = "Error: $e";
        _isGenerating = false;
      });
    }
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

        final text = await noema.documentIngestionService.importDocument(files.first.path!);
        
        setState(() {
          _ideaController.text = text;
          _isGenerating = false;
          _statusText = "Document imported successfully.";
        });
      }
    } catch (e) {
      setState(() {
        _statusText = "Import Error: $e";
        _isGenerating = false;
      });
    }
  }

  void _newProject() {
    noema.bootstrap.projectState.setProject(null);
    setState(() {
      _ideaController.clear();
      _statusText = "New Project Created.";
    });
  }

  Future<void> _saveProject() async {
    final project = noema.bootstrap.projectState.project;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No project to save.")));
      return;
    }
    
    try {
      await noema.saveProject(project);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Project saved successfully.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
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
          provider: noema.bootstrap.imageProvider,
          state: noema.bootstrap.projectState,
        );
        synchronizer.attach(noema.bootstrap.jobEvents);
        noema.bootstrap.jobMonitor.start(project.jobs);
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading project: $e")));
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
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '🎬 Noema Studio',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _newProject,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
              child: const Text('New Project'),
            ),
            MenuItemButton(
              onPressed: _loadProject,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
              child: const Text('Open Project...'),
            ),
            MenuItemButton(
              onPressed: _saveProject,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
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
              child: const Text('Settings'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () {},
              child: const Text('Exit'),
            ),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _generateProject,
              child: const Text('Generate / Run Pipeline'),
            ),
            MenuItemButton(
              onPressed: _importStory,
              child: const Text('Import Script...'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: () {},
              child: const Text('Export Video...'),
            ),
          ],
          child: const Text('Project'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () {},
              child: const Text('Add Scene'),
            ),
            MenuItemButton(
              onPressed: () {},
              child: const Text('Add Character'),
            ),
          ],
          child: const Text('Add'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: _openAdvancedMode,
              child: const Text('Open Workflow Editor (Advanced Mode)'),
            ),
          ],
          child: const Text('Tools'),
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
          _buildMenuBar(context),
          
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
                      pipelineStatus: noema.bootstrap.projectState.pipelineStatus,
                      jobs: project?.jobs ?? [],
                      onGenerate: _generateProject,
                      onImportStory: _importStory,
                    ),
                    
                    // Right Workspace: Video & Storyboard
                    Expanded(
                      child: Column(
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
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                                border: Border(
                                  top: BorderSide(color: Theme.of(context).dividerColor),
                                ),
                              ),
                              child: project != null 
                                ? StoryboardViewWidget(project: project)
                                : const Center(
                                    child: Text(
                                      "Timeline empty. Generate a project to see scenes.",
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  ),
                            ),
                          ),
                        ],
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
