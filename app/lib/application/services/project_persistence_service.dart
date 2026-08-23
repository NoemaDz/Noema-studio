import '../../core/json_project_storage.dart';
import '../../core/noema_project.dart';

class ProjectPersistenceService {



  Future<void> saveProject(
  NoemaProject project,
 ) async {
  final storage = JsonProjectStorage();

  await storage.save(project);

   }

      Future<NoemaProject> openProject(
  String path,
 ) async {
  final storage = JsonProjectStorage();

  return await storage.load(path);
 }

}