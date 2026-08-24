import 'scene.dart';

class Story {
  final String title;
  final List<Scene> scenes;

  Story({required this.title, required this.scenes});

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      title: json["title"],
      scenes: (json["scenes"] as List).map((e) => Scene.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {"title": title, "scenes": scenes.map((e) => e.toJson()).toList()};
  }
}
