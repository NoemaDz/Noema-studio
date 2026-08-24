import 'project_storage.dart';
import 'noema_project.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/story.dart';

class JsonProjectStorage implements ProjectStorage {
  Future<String> getStorageDir(String projectId) async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, "noema", "projects", projectId));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  @override
  Future<void> save(NoemaProject project) async {
    final dir = await getStorageDir(project.id);
    final file = File(p.join(dir, "project.json"));

    await file.writeAsString(encode(project));
  }

  @override
  Future<NoemaProject> load(
    String path, // path to project folder or json
  ) async {
    File file;
    if (path.endsWith('.json')) {
      file = File(path);
    } else {
      file = File(p.join(path, "project.json"));
    }

    if (!await file.exists()) {
      throw Exception("Project file not found at ${file.path}");
    }

    final json = await file.readAsString();

    return decode(json);
  }

  NoemaProject decode(String json) {
    return NoemaProject.fromJson(jsonDecode(json));
  }

  String encode(NoemaProject project) {
    return jsonEncode(project.toJson());
  }

  Story decodeStory(String json) {
    return decode(json).story;
  }
}
