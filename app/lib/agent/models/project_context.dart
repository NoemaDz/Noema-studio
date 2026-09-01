import '../../core/noema_project.dart';

class ProjectContext {
  final String projectId;
  final String title;
  final String idea;
  final List<Map<String, dynamic>> scenes;
  final List<Map<String, dynamic>> characters;

  ProjectContext({
    required this.projectId,
    required this.title,
    required this.idea,
    required this.scenes,
    required this.characters,
  });

  factory ProjectContext.fromProject(NoemaProject project) {
    return ProjectContext(
      projectId: project.id,
      title: project.title,
      idea: project.idea,
      scenes: project.story.scenes
          .map((s) => {'id': s.id.toString(), 'description': s.description})
          .toList(),
      characters: project.characters
          .map((c) => {'id': c.id, 'name': c.name})
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'title': title,
      'idea': idea,
      'scenes': scenes,
      'characters': characters,
    };
  }
}
