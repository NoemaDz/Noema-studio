import 'scene.dart';

class SceneDirective {
  final Scene scene;
  final String imagePrompt; // The enhanced prompt for ComfyUI
  final String?
  voiceoverText; // The text to convert to speech (dialogue + narration)
  final String? cameraEffect; // The effect for FFmpeg (overrides scene default)
  final Map<String, dynamic>
  comfyuiOverrides; // Custom workflow overrides (like LoRAs, IPAdapter refs)

  SceneDirective({
    required this.scene,
    required this.imagePrompt,
    this.voiceoverText,
    this.cameraEffect,
    Map<String, dynamic>? comfyuiOverrides,
  }) : comfyuiOverrides = comfyuiOverrides ?? {};

  factory SceneDirective.fromJson(Map<String, dynamic> json) {
    return SceneDirective(
      scene: Scene.fromJson(json["scene"]),
      imagePrompt: json["imagePrompt"],
      voiceoverText: json["voiceoverText"],
      cameraEffect: json["cameraEffect"],
      comfyuiOverrides: Map<String, dynamic>.from(
        json["comfyuiOverrides"] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "scene": scene.toJson(),
      "imagePrompt": imagePrompt,
      "voiceoverText": voiceoverText,
      "cameraEffect": cameraEffect,
      "comfyuiOverrides": comfyuiOverrides,
    };
  }
}
