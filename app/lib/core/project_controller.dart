import 'noema.dart';
import 'noema_project.dart';
import '../models/story.dart' as import_story;
import 'dart:async';

class ProjectController {
  final Noema noema;

  ProjectController({required this.noema});

  NoemaProject? _project;

  NoemaProject? get project => _project;

  //==================================
  Future<NoemaProject> createProject(String idea) async {
    final p = NoemaProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      idea: idea,
      story: import_story.Story(title: "Generating...", scenes: []),
    );
    _project = await noema.generateProject(p);

    _controller.add(_project!);

    return _project!;
  }

  //==================================
  final StreamController<NoemaProject> _controller =
      StreamController.broadcast();

  Stream<NoemaProject> get stream => _controller.stream;

  void notifyProjectChanged() {
    if (_project != null) {
      _controller.add(_project!);
    }
  }

  bool get hasProject => _project != null;

  Future<void> refresh() async {
    if (_project == null) {
      return;
    }

    notifyProjectChanged();
  }

  void clear() {
    _project = null;
  }

  void updateProgress() {
    if (_project == null) {
      return;
    }

    notifyProjectChanged();
  }
}
