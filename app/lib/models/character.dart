import 'generation_state.dart';

class Character {
  final String id;
  final String name;
  final String description;
  String? prompt;
  String? imagePath;
  String? voiceProfile;
  GenerationState imageState;

  Character({
    required this.id,
    required this.name,
    required this.description,
    this.prompt,
    this.imagePath,
    this.imageState = GenerationState.draft,
    this.voiceProfile,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      prompt: json['prompt'] as String?,
      imagePath: json['imagePath'] as String?,
      imageState: GenerationState.values.firstWhere(
        (e) => e.name == json['imageState'],
        orElse: () => GenerationState.draft,
      ),
      voiceProfile: json['voiceProfile'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      if (prompt != null) 'prompt': prompt,
      if (imagePath != null) 'imagePath': imagePath,
      'imageState': imageState.name,
      if (voiceProfile != null) 'voiceProfile': voiceProfile,
    };
  }
}
