import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/noema.dart';
import 'infrastructure/comfyui/comfyui_plugin.dart';
import 'infrastructure/ollama/ollama_plugin.dart';
import 'infrastructure/tts/flutter_tts_plugin.dart';
import 'infrastructure/ffmpeg/ffmpeg_plugin.dart';
import 'core/plugins/core_pipeline_plugin.dart';
import 'ui/screens/studio_screen.dart';

import 'core/plugins/ingestion_plugin.dart';
import 'infrastructure/openai/openai_plugin.dart';
import 'infrastructure/openai/openai_image_plugin.dart';
import 'application/comfyui_installer_service.dart';
import 'ui/screens/setup_wizard_screen.dart';

import 'core/errors/crash_logger.dart';
import 'ui/widgets/error_boundary.dart';

final noema = Noema();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashLogger.setupGlobalErrorHandler();

  noema.init([
    ComfyUIPlugin(),
    OllamaPlugin(),
    OpenAIPlugin(),
    OpenAIImagePlugin(),
    FlutterTTSPlugin(),
    FFmpegPlugin(),
    IngestionPlugin(),
    CorePipelinePlugin(),
  ]);

  await noema.bootstrap.appSettings.loadSettings();

  runApp(const ErrorBoundary(child: AIStudioApp()));
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0F1E), // Deep dark navy
          surfaceContainerHighest: const Color(0xFF141B2D), // Slightly lighter navy
          primary: const Color(0xFF2196F3), // Vibrant blue
          secondary: const Color(0xFF00E5FF), // Neon cyan
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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
