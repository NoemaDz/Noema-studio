import 'package:flutter/material.dart';
import 'core/noema.dart';
import 'infrastructure/comfyui/comfyui_plugin.dart';
import 'infrastructure/ollama/ollama_plugin.dart';
import 'infrastructure/tts/flutter_tts_plugin.dart';
import 'infrastructure/ffmpeg/ffmpeg_plugin.dart';
import 'core/plugins/core_pipeline_plugin.dart';
import 'ui/screens/studio_screen.dart';

import 'core/plugins/ingestion_plugin.dart';
import 'infrastructure/openai/openai_plugin.dart';
import 'application/comfyui_installer_service.dart';
import 'ui/screens/setup_wizard_screen.dart';

final noema = Noema();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  noema.init([
    ComfyUIPlugin(),
    OllamaPlugin(),
    OpenAIPlugin(),
    FlutterTTSPlugin(),
    FFmpegPlugin(),
    IngestionPlugin(),
    CorePipelinePlugin(),
  ]);

  await noema.bootstrap.appSettings.loadSettings();

  runApp(const AIStudioApp());
}

class AIStudioApp extends StatefulWidget {
  const AIStudioApp({super.key});

  @override
  State<AIStudioApp> createState() => _AIStudioAppState();
}

class _AIStudioAppState extends State<AIStudioApp> {
  final ComfyUIInstallerService _installerService = ComfyUIInstallerService();
  bool _isChecked = false;

  @override
  void initState() {
    super.initState();
    _checkInstaller();
  }

  Future<void> _checkInstaller() async {
    await _installerService.checkInstallation();
    setState(() {
      _isChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AI Studio",
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        fontFamily: 'Segoe UI',
      ),
      home: _isChecked 
          ? (_installerService.isInstalled 
              ? const StudioScreen() 
              : SetupWizardScreen(
                  installerService: _installerService,
                  onComplete: () {
                    setState(() {}); // Rebuilds and goes to StudioScreen
                  },
                ))
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}