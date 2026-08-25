import 'package:flutter/material.dart';
import 'package:noema_studio/main.dart';
import 'package:noema_studio/core/hardware/hardware_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _currentStep = 0;

  late String _activeLlmProvider;
  late TextEditingController _ollamaUrlController;
  late TextEditingController _llmModelNameController;

  late TextEditingController _openAiUrlController;
  late TextEditingController _openAiKeyController;
  late TextEditingController _openAiModelController;

  late TextEditingController _comfyUIUrlController;
  late String _activeImageProvider;
  late String _selectedEffect;

  late String _activeTtsProvider;
  late String _openAiTtsVoice;
  late String _edgeTtsVoice;
  late PerformanceProfile _performanceMode;
  late bool _autoDetectHardware;
  HardwareInfo? _detectedHardware;
  late String _imageResolution;
  late bool _enableVideoGeneration;

  final List<String> _resolutions = [
    '512x512',
    '768x512',
    '512x768',
    '1024x576',
    '576x1024',
  ];

  final List<String> _effects = [
    'random',
    'zoom_in',
    'zoom_out',
    'pan_left',
    'pan_right',
    'pan_up',
    'pan_down',
  ];

  final List<String> _openAiVoices = [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
  ];

  final List<String> _edgeVoices = [
    'en-US-AriaNeural',
    'en-US-ChristopherNeural',
    'en-GB-SoniaNeural',
    'en-GB-RyanNeural',
    'ar-SA-HamedNeural',
    'ar-SA-ZariyahNeural',
  ];

  @override
  void initState() {
    super.initState();
    final settings = noema.bootstrap.appSettings;

    _activeLlmProvider = settings.activeLlmProvider;
    _ollamaUrlController = TextEditingController(text: settings.ollamaUrl);
    _llmModelNameController = TextEditingController(
      text: settings.llmModelName,
    );

    _openAiUrlController = TextEditingController(text: settings.openAiUrl);
    _openAiKeyController = TextEditingController(text: settings.openAiKey);
    _openAiModelController = TextEditingController(text: settings.openAiModel);

    _comfyUIUrlController = TextEditingController(text: settings.comfyUIUrl);
    _activeImageProvider = settings.activeImageProvider;
    _selectedEffect = settings.defaultVideoEffect;
    if (!_effects.contains(_selectedEffect)) {
      _selectedEffect = 'random';
    }

    _activeTtsProvider = settings.activeTtsProvider;
    _openAiTtsVoice = settings.openAiTtsVoice;
    if (!_openAiVoices.contains(_openAiTtsVoice)) {
      _openAiTtsVoice = 'alloy';
    }

    _edgeTtsVoice = settings.edgeTtsVoice;
    if (!_edgeVoices.contains(_edgeTtsVoice)) {
      _edgeTtsVoice = 'en-US-AriaNeural';
    }

    _performanceMode = settings.performanceMode;
    _autoDetectHardware = settings.autoDetectHardware;
    _detectHardware();
    _imageResolution = settings.imageResolution;
    if (!_resolutions.contains(_imageResolution)) {
      _imageResolution = '768x512';
    }
    _enableVideoGeneration = settings.enableVideoGeneration;
  }

  Future<void> _detectHardware() async {
    final info = await HardwareService().detectHardware();
    if (mounted) {
      setState(() {
        _detectedHardware = info;
        if (_autoDetectHardware && !info.isUnknown) {
          _performanceMode = info.recommendedProfile;
        }
      });
    }
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    _llmModelNameController.dispose();
    _openAiUrlController.dispose();
    _openAiKeyController.dispose();
    _openAiModelController.dispose();
    _comfyUIUrlController.dispose();
    super.dispose();
  }

  void _save() {
    if ((_activeLlmProvider == 'openai' ||
            _activeTtsProvider == 'openai_tts' ||
            _activeImageProvider == 'openai_image') &&
        _openAiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your OpenAI API key before saving."),
        ),
      );
      return;
    }

    noema.bootstrap.appSettings.saveSettings(
      ollamaUrl: _ollamaUrlController.text,
      llmModelName: _llmModelNameController.text,
      activeLlmProvider: _activeLlmProvider,
      openAiUrl: _openAiUrlController.text,
      openAiKey: _openAiKeyController.text,
      openAiModel: _openAiModelController.text,
      comfyUIUrl: _comfyUIUrlController.text,
      activeImageProvider: _activeImageProvider,
      defaultVideoEffect: _selectedEffect,
      activeTtsProvider: _activeTtsProvider,
      openAiTtsVoice: _openAiTtsVoice,
      edgeTtsVoice: _edgeTtsVoice,
      performanceMode: _performanceMode,
      autoDetectHardware: _autoDetectHardware,
      imageResolution: _imageResolution,
      enableVideoGeneration: _enableVideoGeneration,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Studio Settings"),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 600,
        height: 600, // Fixed height to prevent dialog jumping
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.deepPurpleAccent),
          ),
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepTapped: (step) => setState(() => _currentStep = step),
            onStepContinue: () {
              if (_currentStep < 3) {
                setState(() => _currentStep += 1);
              } else {
                _save();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                Navigator.of(context).pop();
              }
            },
            controlsBuilder: (context, details) {
              final isLastStep = _currentStep == 3;
              return Padding(
                padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: details.onStepContinue,
                      child: Text(isLastStep ? 'Save & Finish' : 'Continue'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text(
                  'Text Generation Engine (LLM)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Configure the AI brain for scriptwriting',
                ),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.editing,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _activeLlmProvider,
                      decoration: const InputDecoration(
                        labelText: "Active Engine",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ollama',
                          child: Text('Ollama (Local)'),
                        ),
                        DropdownMenuItem(
                          value: 'openai',
                          child: Text('Generic API (OpenAI/Cloud/Local)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _activeLlmProvider = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_activeLlmProvider == 'ollama') ...[
                      TextField(
                        controller: _ollamaUrlController,
                        decoration: const InputDecoration(
                          labelText: "Ollama Base URL",
                          border: OutlineInputBorder(),
                          hintText: "http://localhost:11434",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _llmModelNameController,
                        decoration: const InputDecoration(
                          labelText: "Model Name",
                          border: OutlineInputBorder(),
                          hintText: "qwen3:8b",
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _openAiUrlController,
                        decoration: const InputDecoration(
                          labelText: "API Base URL",
                          border: OutlineInputBorder(),
                          hintText: "https://api.openai.com/v1",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _openAiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "API Key (Bearer Token)",
                          border: OutlineInputBorder(),
                          hintText: "sk-...",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _openAiModelController,
                        decoration: const InputDecoration(
                          labelText: "Model Name",
                          border: OutlineInputBorder(),
                          hintText: "gpt-4o",
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text(
                  'Voice Generation (TTS)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Configure voice actors and narration'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : (_currentStep == 1
                          ? StepState.editing
                          : StepState.indexed),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _activeTtsProvider,
                      decoration: const InputDecoration(
                        labelText: "TTS Engine",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'flutter_tts',
                          child: Text('Local System TTS (Flutter)'),
                        ),
                        DropdownMenuItem(
                          value: 'openai_tts',
                          child: Text('OpenAI TTS API'),
                        ),
                        DropdownMenuItem(
                          value: 'edge_tts',
                          child: Text('Microsoft Edge TTS (Free)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _activeTtsProvider = value);
                        }
                      },
                    ),
                    if (_activeTtsProvider == 'openai_tts') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _openAiTtsVoice,
                        decoration: const InputDecoration(
                          labelText: "OpenAI Voice Model",
                          border: OutlineInputBorder(),
                        ),
                        items: _openAiVoices.map((voice) {
                          return DropdownMenuItem(
                            value: voice,
                            child: Text(voice),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _openAiTtsVoice = value);
                          }
                        },
                      ),
                      if (_activeLlmProvider != 'openai') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _openAiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "OpenAI API Key (Required for TTS)",
                            border: OutlineInputBorder(),
                            hintText: "sk-...",
                          ),
                        ),
                      ],
                    ],
                    if (_activeTtsProvider == 'edge_tts') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _edgeTtsVoice,
                        decoration: const InputDecoration(
                          labelText: "Edge TTS Voice",
                          border: OutlineInputBorder(),
                        ),
                        items: _edgeVoices.map((voice) {
                          return DropdownMenuItem(
                            value: voice,
                            child: Text(voice),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _edgeTtsVoice = value);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text(
                  'Video & Image Engine',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Configure ComfyUI and FFmpeg'),
                isActive: _currentStep >= 2,
                state: _currentStep == 2
                    ? StepState.editing
                    : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _activeImageProvider,
                      decoration: const InputDecoration(
                        labelText: "Active Image Generator",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'comfyui',
                          child: Text('ComfyUI (Local)'),
                        ),
                        DropdownMenuItem(
                          value: 'openai_image',
                          child: Text('OpenAI DALL-E 3 (Cloud)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _activeImageProvider = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_activeImageProvider == 'comfyui') ...[
                      TextField(
                        controller: _comfyUIUrlController,
                        decoration: const InputDecoration(
                          labelText: "ComfyUI Base URL",
                          border: OutlineInputBorder(),
                          hintText: "http://127.0.0.1:8188",
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      if (_activeLlmProvider != 'openai' &&
                          _activeTtsProvider != 'openai_tts') ...[
                        TextField(
                          controller: _openAiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "OpenAI API Key (Required for DALL-E 3)",
                            border: OutlineInputBorder(),
                            hintText: "sk-...",
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _selectedEffect,
                      decoration: const InputDecoration(
                        labelText: "Default FFmpeg Camera Effect",
                        border: OutlineInputBorder(),
                      ),
                      items: _effects.map((effect) {
                        return DropdownMenuItem(
                          value: effect,
                          child: Text(effect),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedEffect = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              // ── Step 3: Quality & Character Consistency ──────────────────
              Step(
                title: const Text(
                  'Quality & Character Consistency',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'FaceDetailer · PersonDetailer · Resolution',
                ),
                isActive: _currentStep >= 3,
                state: _currentStep == 3
                    ? StepState.editing
                    : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Performance Mode ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_detectedHardware != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.memory,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _detectedHardware!.isUnknown
                                        ? 'Hardware: Unknown'
                                        : 'Hardware: ${_detectedHardware!.gpuName} (${_detectedHardware!.vramMB} MB)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              const Text('Auto-Detect Profile'),
                              const Spacer(),
                              Switch(
                                value: _autoDetectHardware,
                                onChanged: (val) {
                                  setState(() {
                                    _autoDetectHardware = val;
                                    if (val &&
                                        _detectedHardware != null &&
                                        !_detectedHardware!.isUnknown) {
                                      _performanceMode =
                                          _detectedHardware!.recommendedProfile;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PerformanceProfile>(
                            initialValue: _performanceMode,
                            decoration: const InputDecoration(
                              labelText: 'Performance Profile',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: PerformanceProfile.fast,
                                child: Text('Fast (Low VRAM - No Detailers)'),
                              ),
                              DropdownMenuItem(
                                value: PerformanceProfile.balanced,
                                child: Text(
                                  'Balanced (Medium VRAM - Face Detailer Only)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: PerformanceProfile.ultra,
                                child: Text(
                                  'Ultra (High VRAM - Face & Person Detailers)',
                                ),
                              ),
                            ],
                            onChanged: _autoDetectHardware
                                ? null
                                : (val) {
                                    if (val != null)
                                      setState(() => _performanceMode = val);
                                  },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Video Generation Toggle ─────────────────────────────
                    SwitchListTile(
                      title: const Text('Enable AI Video Generation (I2V)'),
                      subtitle: const Text(
                        'Generates animated video clips instead of static images. Slower, but creates real videos.',
                      ),
                      value: _enableVideoGeneration,
                      onChanged: (val) {
                        setState(() => _enableVideoGeneration = val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 16),

                    // ── Resolution dropdown ───────────────────────────────
                    DropdownButtonFormField<String>(
                      initialValue: _imageResolution,
                      decoration: const InputDecoration(
                        labelText: 'Image Resolution',
                        border: OutlineInputBorder(),
                        helperText:
                            'Wide (768×512) recommended for scenes — Portrait (512×768) for close-ups',
                      ),
                      items: _resolutions.map((r) {
                        String label;
                        switch (r) {
                          case '512x512':
                            label = '512×512  — Square';
                          case '768x512':
                            label = '768×512  — Wide Landscape (recommended)';
                          case '512x768':
                            label = '512×768  — Portrait';
                          case '1024x576':
                            label = '1024×576  — HD Landscape (slow)';
                          case '576x1024':
                            label = '576×1024  — HD Portrait (slow)';
                          default:
                            label = r;
                        }
                        return DropdownMenuItem(value: r, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _imageResolution = v);
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    // Info card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'FaceDetailer requires face_yolov8m.pt and PersonDetailer requires person_yolov8m-seg.pt. Both are already installed.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
