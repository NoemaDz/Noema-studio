import '../core/noema_project.dart';

class ProjectStatistics {
  final NoemaProject project;

  ProjectStatistics(this.project);

  int get sceneCount {
    return project.story.scenes.length;
  }

  int get characterCount {
    return project.characters.length;
  }

  int get imageCount {
    return project.images.length;
  }
}
