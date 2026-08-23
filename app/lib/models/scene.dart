class DialogueLine {
  final String? characterName;
  final String text;

  DialogueLine({this.characterName, required this.text});

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    return DialogueLine(
      characterName: json["characterName"],
      text: json["text"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "characterName": characterName,
      "text": text,
    };
  }
}

class Scene {
  final int id;
  final String description;
  String? imagePrompt;
  String? imagePath;

  // === Agent Director Fields ===
  List<DialogueLine> dialogue;
  String? narration;
  List<String> characterNames;
  Map<String, String> characterPositions; // Name -> Position (left, right, center)
  String? mood;
  String? cameraEffect;
  String? colorGrading;
  String? transition;
  int? estimatedDurationSeconds;
  Map<String, dynamic> extras;

  Scene({
    required this.id,
    required this.description,
    this.imagePrompt,
    this.imagePath,
    this.dialogue = const [],
    this.narration,
    this.characterNames = const [],
    this.characterPositions = const {},
    this.mood,
    this.cameraEffect,
    this.colorGrading,
    this.transition,
    this.estimatedDurationSeconds,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? {};

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json["id"],
      description: json["description"],
      imagePrompt: json["imagePrompt"],
      imagePath: json["imagePath"],
      dialogue: (json["dialogue"] as List<dynamic>?)
              ?.map((e) => DialogueLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      narration: json["narration"],
      characterNames: List<String>.from(json["characterNames"] ?? []),
      characterPositions: Map<String, String>.from(json["characterPositions"] ?? {}),
      mood: json["mood"],
      cameraEffect: json["cameraEffect"],
      colorGrading: json["colorGrading"],
      transition: json["transition"],
      estimatedDurationSeconds: json["estimatedDurationSeconds"],
      extras: Map<String, dynamic>.from(json["extras"] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "description": description,
      "imagePrompt": imagePrompt,
      "imagePath": imagePath,
      "dialogue": dialogue.map((e) => e.toJson()).toList(),
      "narration": narration,
      "characterNames": characterNames,
      "characterPositions": characterPositions,
      "mood": mood,
      "cameraEffect": cameraEffect,
      "colorGrading": colorGrading,
      "transition": transition,
      "estimatedDurationSeconds": estimatedDurationSeconds,
      "extras": extras,
    };
  }
}