import 'generation_state.dart';

class Character {
  final String id;
  final String name;
  final String description;
  String? prompt;
  String? imagePath;
  GenerationState imageState;

  Character({
    required this.id,
    required this.name,
    required this.description,
    this.prompt,
    this.imagePath,
    this.imageState = GenerationState.draft,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json["id"] ?? json["name"], // fallback to name for backward compatibility
      name: json["name"],
      description: json["description"],
      prompt: json["prompt"],
      imagePath: json["imagePath"],
      imageState: GenerationStateExtension.fromJson(json["imageState"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "prompt": prompt,
      "imagePath": imagePath,
      "imageState": imageState.toJson(),
    };
  }
}