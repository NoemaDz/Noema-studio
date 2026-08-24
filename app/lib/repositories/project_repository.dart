import '../core/noema_project.dart';

/// Repository for managing in-memory project list.
/// Uses [NoemaProject] as the single canonical project model.
class ProjectRepository {
  final List<NoemaProject> projects = [];

  void add(NoemaProject project) {
    projects.add(project);
  }

  List<NoemaProject> getAll() {
    return projects;
  }

  NoemaProject? findById(String id) {
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void remove(String id) {
    projects.removeWhere((p) => p.id == id);
  }
}