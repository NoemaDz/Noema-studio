import 'dart:async';

class TaskNode {
  final String id;
  final String name;
  final Future<void> Function() execute;
  final List<TaskNode> dependencies;

  bool isCompleted = false;
  bool isFailed = false;
  bool isRunning = false;

  TaskNode({
    required this.id,
    required this.name,
    required this.execute,
    this.dependencies = const [],
  });

  bool get canRun =>
      !isCompleted &&
      !isFailed &&
      !isRunning &&
      dependencies.every((dep) => dep.isCompleted);
}
