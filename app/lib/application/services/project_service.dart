import '../../core/noema_project.dart';
import '../../models/project_task.dart';
import '../../models/task.dart';
import '../../models/task_status.dart';

class ProjectService {
  ProjectTask addTask(NoemaProject project, TaskType type) {
    final task = ProjectTask(type: type);

    project.tasks.add(task);

    return task;
  }

  Future<void> runTask({
    required NoemaProject project,
    required TaskType type,
    required Future<void> Function() action,
  }) async {
    final task = addTask(project, type);

    startTask(task);

    try {
      await action();

      finishTask(task);
    } catch (e) {
      task.status = TaskStatus.failed;
      task.message = e.toString();
      rethrow;
    }
  }

  void startTask(ProjectTask task) {
    task.status = TaskStatus.running;
    task.progress = 0;
  }

  void finishTask(ProjectTask task) {
    task.status = TaskStatus.completed;
    task.progress = 1;
  }
}
