import 'package:flutter/material.dart';
import '../../main.dart'; // To access global noema

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
  late String _selectedEffect;

  late String _activeTtsProvider;
  late String _openAiTtsVoice;
  late String _edgeTtsVoice;

  final List<String> _effects = [
    'random',
    'zoom_in',
    'zoom_out',
    'pan_left',
    'pan_right',
    'pan_up',
    'pan_down'
  ];

  final List<String> _openAiVoices = [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer'
  ];

  final List<String> _edgeVoices = [
    'en-US-AriaNeural',
    'en-US-ChristopherNeural',
    'en-GB-SoniaNeural',
    'en-GB-RyanNeural',
    'ar-SA-HamedNeural',
    'ar-SA-ZariyahNeural'
  ];

  @override
  void initState() {
    super.initState();
    final settings = noema.bootstrap.appSettings;
    
    _activeLlmProvider = settings.activeLlmProvider;
    _ollamaUrlController = TextEditingController(text: settings.ollamaUrl);
    _llmModelNameController = TextEditingController(text: settings.llmModelName);
    
    _openAiUrlController = TextEditingController(text: settings.openAiUrl);
    _openAiKeyController = TextEditingController(text: settings.openAiKey);
    _openAiModelController = TextEditingController(text: settings.openAiModel);

    _comfyUIUrlController = TextEditingController(text: settings.comfyUIUrl);
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
    noema.bootstrap.appSettings.saveSettings(
      ollamaUrl: _ollamaUrlController.text,
      llmModelName: _llmModelNameController.text,
      activeLlmProvider: _activeLlmProvider,
      openAiUrl: _openAiUrlController.text,
      openAiKey: _openAiKeyController.text,
      openAiModel: _openAiModelController.text,
      comfyUIUrl: _comfyUIUrlController.text,
      defaultVideoEffect: _selectedEffect,
      activeTtsProvider: _activeTtsProvider,
      openAiTtsVoice: _openAiTtsVoice,
      edgeTtsVoice: _edgeTtsVoice,
    );
    Navigator.of(context).pop();
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.deepPurpleAccent,
            ),
          ),
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepTapped: (step) => setState(() => _currentStep = step),
            onStepContinue: () {
              if (_currentStep < 2) {
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
              final isLastStep = _currentStep == 2;
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
                title: const Text('Text Generation Engine (LLM)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configure the AI brain for scriptwriting'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.editing,
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
                        DropdownMenuItem(value: 'ollama', child: Text('Ollama (Local)')),
                        DropdownMenuItem(value: 'openai', child: Text('Generic API (OpenAI/Cloud/Local)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _activeLlmProvider = value);
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
                title: const Text('Voice Generation (TTS)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configure voice actors and narration'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : (_currentStep == 1 ? StepState.editing : StepState.indexed),
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
                        DropdownMenuItem(value: 'flutter_tts', child: Text('Local System TTS (Flutter)')),
                        DropdownMenuItem(value: 'openai_tts', child: Text('OpenAI TTS API')),
                        DropdownMenuItem(value: 'edge_tts', child: Text('Microsoft Edge TTS (Free)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _activeTtsProvider = value);
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
                          if (value != null) setState(() => _openAiTtsVoice = value);
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
                          if (value != null) setState(() => _edgeTtsVoice = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Step(
                title: const Text('Video & Image Engine', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Configure ComfyUI and FFmpeg'),
                isActive: _currentStep >= 2,
                state: _currentStep == 2 ? StepState.editing : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    TextField(
                      controller: _comfyUIUrlController,
                      decoration: const InputDecoration(
                        labelText: "ComfyUI Base URL",
                        border: OutlineInputBorder(),
                        hintText: "http://127.0.0.1:8188",
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        if (value != null) setState(() => _selectedEffect = value);
                      },
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
