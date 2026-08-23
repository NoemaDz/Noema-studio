class Character {
  final String id;
  final String name;
  final String description;
  String? prompt;
  String? imagePath;

  Character({
    required this.id,
    required this.name,
    required this.description,
    this.prompt,
    this.imagePath,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json["id"] ?? json["name"], // fallback to name for backward compatibility
      name: json["name"],
      description: json["description"],
      prompt: json["prompt"],
      imagePath: json["imagePath"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "description": description,
      "prompt": prompt,
      "imagePath": imagePath,
    };
  }
}