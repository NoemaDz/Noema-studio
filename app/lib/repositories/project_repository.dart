import '../models/project.dart';

class ProjectRepository {
  final List<Project> projects = [];

  void add(Project project) {
    projects.add(project);
  }

  List<Project> getAll() {
    return projects;
  }
}