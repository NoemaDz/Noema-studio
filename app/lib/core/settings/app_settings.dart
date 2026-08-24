import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kOllamaUrl = 'ollama_url';
  static const _kLlmModelName = 'llm_model_name';
  static const _kActiveLlmProvider = 'active_llm_provider';
  static const _kOpenAiUrl = 'openai_url';
  static const _kOpenAiKey = 'openai_key';
  static const _kOpenAiModel = 'openai_model';
  static const _kComfyUIUrl = 'comfyui_url';
  static const _kDefaultVideoEffect = 'default_video_effect';

  static const _kActiveTtsProvider = 'active_tts_provider';
  static const _kOpenAiTtsVoice = 'openai_tts_voice';
  static const _kEdgeTtsVoice = 'edge_tts_voice';

  String _ollamaUrl = 'http://localhost:11434';
  String _llmModelName = 'qwen3:8b';
  String _activeLlmProvider = 'ollama'; // 'ollama' or 'openai'
  String _openAiUrl = 'https://api.openai.com/v1';
  String _openAiKey = '';
  String _openAiModel = 'gpt-4o';
  String _comfyUIUrl = 'http://127.0.0.1:8188';
  String _defaultVideoEffect = 'zoom_in';
  String _activeTtsProvider = 'flutter_tts';
  String _openAiTtsVoice = 'alloy';
  String _edgeTtsVoice = 'en-US-AriaNeural';

  String get ollamaUrl => _ollamaUrl;
  String get llmModelName => _llmModelName;
  String get activeLlmProvider => _activeLlmProvider;
  String get openAiUrl => _openAiUrl;
  String get openAiKey => _openAiKey;
  String get openAiModel => _openAiModel;
  String get comfyUIUrl => _comfyUIUrl;
  String get defaultVideoEffect => _defaultVideoEffect;
  String get activeTtsProvider => _activeTtsProvider;
  String get openAiTtsVoice => _openAiTtsVoice;
  String get edgeTtsVoice => _edgeTtsVoice;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ollamaUrl = prefs.getString(_kOllamaUrl) ?? 'http://localhost:11434';
    _llmModelName = prefs.getString(_kLlmModelName) ?? 'qwen2.5:3b';
    _activeLlmProvider = prefs.getString(_kActiveLlmProvider) ?? 'ollama';
    _openAiUrl = prefs.getString(_kOpenAiUrl) ?? 'https://api.openai.com/v1';
    _openAiKey = prefs.getString(_kOpenAiKey) ?? '';
    _openAiModel = prefs.getString(_kOpenAiModel) ?? 'gpt-4o';
    _comfyUIUrl = prefs.getString(_kComfyUIUrl) ?? 'http://127.0.0.1:8188';
    _defaultVideoEffect = prefs.getString(_kDefaultVideoEffect) ?? 'zoom_in';
    _activeTtsProvider = prefs.getString(_kActiveTtsProvider) ?? 'flutter_tts';
    _openAiTtsVoice = prefs.getString(_kOpenAiTtsVoice) ?? 'alloy';
    _edgeTtsVoice = prefs.getString(_kEdgeTtsVoice) ?? 'en-US-AriaNeural';
    notifyListeners();
  }

  Future<void> saveSettings({
    required String ollamaUrl,
    required String llmModelName,
    required String activeLlmProvider,
    required String openAiUrl,
    required String openAiKey,
    required String openAiModel,
    required String comfyUIUrl,
    required String defaultVideoEffect,
    required String activeTtsProvider,
    required String openAiTtsVoice,
    required String edgeTtsVoice,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kOllamaUrl, ollamaUrl);
    await prefs.setString(_kLlmModelName, llmModelName);
    await prefs.setString(_kActiveLlmProvider, activeLlmProvider);
    await prefs.setString(_kOpenAiUrl, openAiUrl);
    await prefs.setString(_kOpenAiKey, openAiKey);
    await prefs.setString(_kOpenAiModel, openAiModel);
    await prefs.setString(_kComfyUIUrl, comfyUIUrl);
    await prefs.setString(_kDefaultVideoEffect, defaultVideoEffect);
    await prefs.setString(_kActiveTtsProvider, activeTtsProvider);
    await prefs.setString(_kOpenAiTtsVoice, openAiTtsVoice);
    await prefs.setString(_kEdgeTtsVoice, edgeTtsVoice);

    _ollamaUrl = ollamaUrl;
    _llmModelName = llmModelName;
    _activeLlmProvider = activeLlmProvider;
    _openAiUrl = openAiUrl;
    _openAiKey = openAiKey;
    _openAiModel = openAiModel;
    _comfyUIUrl = comfyUIUrl;
    _defaultVideoEffect = defaultVideoEffect;
    _activeTtsProvider = activeTtsProvider;
    _openAiTtsVoice = openAiTtsVoice;
    _edgeTtsVoice = edgeTtsVoice;

    notifyListeners();
  }
}
