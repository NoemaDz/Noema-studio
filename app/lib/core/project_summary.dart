import 'noema_project.dart';

class ProjectSummary {
  final NoemaProject project;

  ProjectSummary(this.project);

  String get title {
  return project.story.title;
 }

 int get scenes {
  return project.statistics.sceneCount;
 }

 int get characters {
  return project.statistics.characterCount;
 }

 int get images {
  return project.statistics.imageCount;
 }

 int get progress {
  return project.progress.percent;
 }
}