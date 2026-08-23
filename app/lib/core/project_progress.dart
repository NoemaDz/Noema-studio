import '../models/project_task.dart';
import '../models/task_status.dart';







class ProjectProgress {
  final List<ProjectTask> tasks;

  ProjectProgress(this.tasks);

  double get value {
  if (tasks.isEmpty) {
    return 0;
  }

  final completed = tasks.where(
  (task) => task.isCompleted,
  ).length;

  return completed / tasks.length;
 }
 int get percent {
  
  return (value * 100).round();
 }
 int get runningTasks {
  return tasks.where(
    (task) => task.status == TaskStatus.running,
  ).length;
 }
 int get pendingTasks {
  return tasks.where(
    (task) => task.status == TaskStatus.pending,
  ).length;
 }
 int get failedTasks {
  return tasks.where(
    (task) => task.status == TaskStatus.failed,
  ).length;
 }
 int get completedTasks {
  return tasks.where(
    (task) => task.isCompleted,
  ).length;
 }
 int get totalTasks {
  return tasks.length;
 }
 bool get isFinished {
  return completedTasks == totalTasks &&
      totalTasks > 0;
 }
}