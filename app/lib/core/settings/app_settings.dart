import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:noema_studio/core/hardware/hardware_service.dart';

class AppSettings extends ChangeNotifier {
  static const _kOllamaUrl = 'ollama_url';
  static const _kLlmModelName = 'llm_model_name';
  static const _kActiveLlmProvider = 'active_llm_provider';
  static const _kOpenAiUrl = 'openai_url';
  // NOTE: openai_key is intentionally NOT in SharedPreferences (stored in Secure Storage)
  static const _kOpenAiKeySecure = 'openai_key';
  static const _kOpenAiModel = 'openai_model';

  static const _kGeminiImageKeySecure = 'gemini_image_key';
  static const _kGeminiImageModel = 'gemini_image_model';
  static const _kGeminiImageAspectRatio = 'gemini_image_aspect_ratio';
  static const _kGeminiImageResolution = 'gemini_image_resolution';

  static const _kGeminiVideoKeySecure = 'gemini_video_key';

  static const _kComfyUIUrl = 'comfyui_url';
  static const _kActiveImageProvider = 'active_image_provider';
  static const _kActiveVideoProvider = 'active_video_provider';
  static const _kGeminiVideoModel = 'gemini_video_model';
  static const _kDefaultVideoEffect = 'default_video_effect';

  static const _kActiveTtsProvider = 'active_tts_provider';
  static const _kOpenAiTtsVoice = 'openai_tts_voice';
  static const _kEdgeTtsVoice = 'edge_tts_voice';
  static const _kPerformanceMode = 'performance_mode';
  static const _kAutoDetectHardware = 'auto_detect_hardware';
  static const _kImageResolution = 'image_resolution';
  static const _kEnableVideoGeneration = 'enable_video_generation';

  String _ollamaUrl = 'http://localhost:11434';
  String _llmModelName = 'qwen3:8b';
  String _activeLlmProvider = 'ollama'; // 'ollama' or 'openai'
  String _openAiUrl = 'https://api.openai.com/v1';
  String _openAiKey = '';
  String _openAiModel = 'gpt-4o';

  String _geminiImageKey = '';
  String _geminiImageModel = 'gemini-3.1-flash-image';
  String _geminiImageAspectRatio = '16:9';
  String _geminiImageResolution = '1K';

  String _geminiVideoKey = '';

  String _comfyUIUrl = 'http://127.0.0.1:8188';
  String _activeImageProvider = 'comfyui';
  String _activeVideoProvider = 'gemini_video';
  String _geminiVideoModel = 'veo-3.1-generate-preview';
  String _defaultVideoEffect = 'zoom_in';
  String _activeTtsProvider = 'flutter_tts';
  String _openAiTtsVoice = 'alloy';
  String _edgeTtsVoice = 'en-US-AriaNeural';
  PerformanceProfile _performanceMode = PerformanceProfile.balanced;
  bool _autoDetectHardware = true;
  String _imageResolution = '768x512'; // wide landscape
  bool _enableVideoGeneration = false;

  // Secure storage instance (uses platform Keychain/KeyStore/Secret Service)
  static const _secureStorage = FlutterSecureStorage(lOptions: LinuxOptions());

  String get ollamaUrl => _ollamaUrl;
  String get llmModelName => _llmModelName;
  String get activeLlmProvider => _activeLlmProvider;
  String get openAiUrl => _openAiUrl;
  String get openAiKey => _openAiKey;
  String get openAiModel => _openAiModel;

  String get geminiImageKey => _geminiImageKey;
  String get geminiImageModel => _geminiImageModel;
  String get geminiImageAspectRatio => _geminiImageAspectRatio;
  String get geminiImageResolution => _geminiImageResolution;

  /// Returns the Gemini Video API key, falling back to the image key if empty.
  String get geminiVideoKey =>
      _geminiVideoKey.isNotEmpty ? _geminiVideoKey : _geminiImageKey;

  /// Returns the raw stored Gemini Video API key without fallback (empty if not set).
  String get geminiVideoKeyRaw => _geminiVideoKey;

  String get comfyUIUrl => _comfyUIUrl;
  String get activeImageProvider => _activeImageProvider;
  String get activeVideoProvider => _activeVideoProvider;
  String get geminiVideoModel => _geminiVideoModel;
  String get defaultVideoEffect => _defaultVideoEffect;
  String get activeTtsProvider => _activeTtsProvider;
  String get openAiTtsVoice => _openAiTtsVoice;
  String get edgeTtsVoice => _edgeTtsVoice;
  PerformanceProfile get performanceMode => _performanceMode;
  bool get autoDetectHardware => _autoDetectHardware;
  String get imageResolution => _imageResolution;
  bool get enableVideoGeneration => _enableVideoGeneration;
  int? get mockVramGB => null; // Mock property for hardware testing

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ollamaUrl = prefs.getString(_kOllamaUrl) ?? 'http://localhost:11434';
    _llmModelName = prefs.getString(_kLlmModelName) ?? 'qwen2.5:3b';
    _activeLlmProvider = prefs.getString(_kActiveLlmProvider) ?? 'ollama';
    _openAiUrl = prefs.getString(_kOpenAiUrl) ?? 'https://api.openai.com/v1';

    // Load OpenAI API key securely
    String? secureOpenAiKey;
    try {
      secureOpenAiKey = await _secureStorage.read(key: _kOpenAiKeySecure);
    } catch (e) {
      secureOpenAiKey = null;
    }
    if (secureOpenAiKey == null) {
      final legacyKey = prefs.getString(_kOpenAiKeySecure);
      if (legacyKey != null && legacyKey.isNotEmpty) {
        try {
          await _secureStorage.write(key: _kOpenAiKeySecure, value: legacyKey);
        } catch (_) {}
        await prefs.remove(_kOpenAiKeySecure);
        secureOpenAiKey = legacyKey;
      } else {
        secureOpenAiKey = '';
      }
    }
    _openAiKey = secureOpenAiKey;
    _openAiModel = prefs.getString(_kOpenAiModel) ?? 'gpt-4o';

    // Load Gemini API key securely
    String? secureGeminiKey;
    try {
      secureGeminiKey = await _secureStorage.read(key: _kGeminiImageKeySecure);
    } catch (e) {
      secureGeminiKey = '';
    }
    _geminiImageKey = secureGeminiKey ?? '';

    // Load Gemini Video API key securely
    String? secureGeminiVideoKey;
    try {
      secureGeminiVideoKey = await _secureStorage.read(
        key: _kGeminiVideoKeySecure,
      );
    } catch (e) {
      secureGeminiVideoKey = '';
    }
    _geminiVideoKey = secureGeminiVideoKey ?? '';
    _geminiImageModel =
        prefs.getString(_kGeminiImageModel) ?? 'gemini-3.1-flash-image';
    _geminiImageAspectRatio =
        prefs.getString(_kGeminiImageAspectRatio) ?? '16:9';
    _geminiImageResolution = prefs.getString(_kGeminiImageResolution) ?? '1K';

    _comfyUIUrl = prefs.getString(_kComfyUIUrl) ?? 'http://127.0.0.1:8188';
    _activeImageProvider = prefs.getString(_kActiveImageProvider) ?? 'comfyui';
    _activeVideoProvider =
        prefs.getString(_kActiveVideoProvider) ?? 'gemini_video';
    _geminiVideoModel =
        prefs.getString(_kGeminiVideoModel) ?? 'veo-3.1-generate-preview';
    _defaultVideoEffect = prefs.getString(_kDefaultVideoEffect) ?? 'zoom_in';
    _activeTtsProvider = prefs.getString(_kActiveTtsProvider) ?? 'flutter_tts';
    _openAiTtsVoice = prefs.getString(_kOpenAiTtsVoice) ?? 'alloy';
    _edgeTtsVoice = prefs.getString(_kEdgeTtsVoice) ?? 'en-US-AriaNeural';

    final perfStr = prefs.getString(_kPerformanceMode) ?? 'balanced';
    _performanceMode = PerformanceProfile.values.firstWhere(
      (e) => e.toString().split('.').last == perfStr,
      orElse: () => PerformanceProfile.balanced,
    );
    _autoDetectHardware = prefs.getBool(_kAutoDetectHardware) ?? true;
    _imageResolution = prefs.getString(_kImageResolution) ?? '768x512';
    _enableVideoGeneration = prefs.getBool(_kEnableVideoGeneration) ?? false;
    notifyListeners();
  }

  static String sanitizeUrl(String url, {String defaultUrl = ''}) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return defaultUrl;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<void> saveSettings({
    required String ollamaUrl,
    required String llmModelName,
    required String activeLlmProvider,
    required String openAiUrl,
    required String openAiKey,
    required String openAiModel,
    required String geminiImageKey,
    required String geminiVideoKey,
    required String geminiImageModel,
    required String geminiImageAspectRatio,
    required String geminiImageResolution,
    required String comfyUIUrl,
    required String activeImageProvider,
    required String activeVideoProvider,
    required String geminiVideoModel,
    required String defaultVideoEffect,
    required String activeTtsProvider,
    required String openAiTtsVoice,
    required String edgeTtsVoice,
    required PerformanceProfile performanceMode,
    required bool autoDetectHardware,
    required String imageResolution,
    required bool enableVideoGeneration,
  }) async {
    final cleanOllama = sanitizeUrl(
      ollamaUrl,
      defaultUrl: 'http://localhost:11434',
    );
    final cleanOpenAiUrl = sanitizeUrl(
      openAiUrl,
      defaultUrl: 'https://api.openai.com/v1',
    );
    final cleanComfyUIUrl = sanitizeUrl(
      comfyUIUrl,
      defaultUrl: 'http://127.0.0.1:8188',
    );

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kOllamaUrl, cleanOllama);
    await prefs.setString(_kLlmModelName, llmModelName.trim());
    await prefs.setString(_kActiveLlmProvider, activeLlmProvider);
    await prefs.setString(_kOpenAiUrl, cleanOpenAiUrl);

    // Save API keys securely
    try {
      await _secureStorage.write(
        key: _kOpenAiKeySecure,
        value: openAiKey.trim(),
      );
      await _secureStorage.write(
        key: _kGeminiImageKeySecure,
        value: geminiImageKey.trim(),
      );
      await _secureStorage.write(
        key: _kGeminiVideoKeySecure,
        value: geminiVideoKey.trim(),
      );
    } catch (_) {} // Ignore in tests

    await prefs.setString(_kOpenAiModel, openAiModel.trim());

    await prefs.setString(_kGeminiImageModel, geminiImageModel.trim());
    await prefs.setString(_kGeminiImageAspectRatio, geminiImageAspectRatio);
    await prefs.setString(_kGeminiImageResolution, geminiImageResolution);

    await prefs.setString(_kComfyUIUrl, cleanComfyUIUrl);
    await prefs.setString(_kActiveImageProvider, activeImageProvider);
    await prefs.setString(_kActiveVideoProvider, activeVideoProvider);
    await prefs.setString(_kGeminiVideoModel, geminiVideoModel.trim());
    await prefs.setString(_kDefaultVideoEffect, defaultVideoEffect);
    await prefs.setString(_kActiveTtsProvider, activeTtsProvider);
    await prefs.setString(_kOpenAiTtsVoice, openAiTtsVoice);
    await prefs.setString(_kEdgeTtsVoice, edgeTtsVoice);
    await prefs.setString(
      _kPerformanceMode,
      performanceMode.toString().split('.').last,
    );
    await prefs.setBool(_kAutoDetectHardware, autoDetectHardware);
    await prefs.setString(_kImageResolution, imageResolution);
    await prefs.setBool(_kEnableVideoGeneration, enableVideoGeneration);

    _ollamaUrl = cleanOllama;
    _llmModelName = llmModelName.trim();
    _activeLlmProvider = activeLlmProvider;
    _openAiUrl = cleanOpenAiUrl;
    _openAiKey = openAiKey.trim();
    _openAiModel = openAiModel.trim();

    _geminiImageKey = geminiImageKey.trim();
    _geminiVideoKey = geminiVideoKey.trim();
    _geminiImageModel = geminiImageModel.trim();
    _geminiImageAspectRatio = geminiImageAspectRatio;
    _geminiImageResolution = geminiImageResolution;

    _comfyUIUrl = cleanComfyUIUrl;
    _activeImageProvider = activeImageProvider;
    _activeVideoProvider = activeVideoProvider;
    _geminiVideoModel = geminiVideoModel.trim();
    _defaultVideoEffect = defaultVideoEffect;
    _activeTtsProvider = activeTtsProvider;
    _openAiTtsVoice = openAiTtsVoice;
    _edgeTtsVoice = edgeTtsVoice;
    _performanceMode = performanceMode;
    _autoDetectHardware = autoDetectHardware;
    _imageResolution = imageResolution;
    _enableVideoGeneration = enableVideoGeneration;

    notifyListeners();
  }
}
