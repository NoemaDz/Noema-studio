import 'noema_project.dart';

abstract class ProjectStorage {
  Future<void> save(NoemaProject project);

  Future<NoemaProject> load(String path);
}
