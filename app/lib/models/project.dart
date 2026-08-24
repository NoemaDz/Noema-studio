import 'character.dart';
import 'story.dart';
import 'style.dart';
import 'generation_state.dart';

class Project {

  final String id;

  final String title;

  final String idea;

  final String language;

  final Style style;

  final String imageModel;

  final String llmModel;

  final DateTime createdAt;

  Story? story;

  final List<Character> characters;

  GenerationState projectState;

  Project({

    required this.id,

    required this.title,

    required this.idea,

    required this.language,

    required this.style,

    required this.imageModel,

    required this.llmModel,

    required this.createdAt,

    this.story,
    this.characters = const [],
    this.projectState = GenerationState.draft,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json["id"],
      title: json["title"],
      idea: json["idea"],
      language: json["language"],
      style: Style.fromJson(json["style"]),
      imageModel: json["imageModel"],
      llmModel: json["llmModel"],
      createdAt: DateTime.parse(json["createdAt"]),
      story: json["story"] != null ? Story.fromJson(json["story"]) : null,
      characters: (json["characters"] as List<dynamic>?)
              ?.map((e) => Character.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      projectState: GenerationStateExtension.fromJson(json["projectState"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "idea": idea,
      "language": language,
      "style": style.toJson(),
      "imageModel": imageModel,
      "llmModel": llmModel,
      "createdAt": createdAt.toIso8601String(),
      "story": story?.toJson(),
      "characters": characters.map((e) => e.toJson()).toList(),
      "projectState": projectState.toJson(),
    };
  }
}