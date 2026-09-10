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
import 'infrastructure/gemini/gemini_plugin.dart';
import 'application/comfyui_installer_service.dart';
import 'ui/screens/setup_wizard_screen.dart';

import 'core/errors/crash_logger.dart';
import 'ui/widgets/error_boundary.dart';

import 'core/settings/platform_paths.dart';

final noema = Noema();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashLogger.setupGlobalErrorHandler();

  await PlatformPaths.instance.init();

  noema.init([
    ComfyUIPlugin(),
    OllamaPlugin(),
    OpenAIPlugin(),
    OpenAIImagePlugin(),
    GeminiPlugin(),
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        dividerColor: Colors.white10,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E), // Sidebar/Panel color
          surfaceContainerHighest: const Color(0xFF2C2C2C),
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF00E5FF),
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
