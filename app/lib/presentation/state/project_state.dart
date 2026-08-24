import 'package:flutter/foundation.dart';

import '../../core/noema_project.dart';

class ProjectState extends ChangeNotifier {
  NoemaProject? _project;

  NoemaProject? get project => _project;
  
  String _pipelineStatus = "";
  String get pipelineStatus => _pipelineStatus;

  void setProject(NoemaProject? project) {
    _project = project;
    notifyListeners();
  }
  
  void setPipelineStatus(String status) {
    _pipelineStatus = status;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  void clear() {
    _project = null;
    notifyListeners();
  }
}