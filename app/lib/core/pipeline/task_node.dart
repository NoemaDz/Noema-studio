import 'dart:async';

class TaskNode {
  final String id;
  final String name;
  final Future<void> Function() execute;
  final void Function()? onCancel;
  final List<TaskNode> dependencies;
  final bool requiresGPU;

  bool isCompleted = false;
  bool isFailed = false;
  bool isRunning = false;

  TaskNode({
    required this.id,
    required this.name,
    required this.execute,
    this.onCancel,
    this.dependencies = const [],
    this.requiresGPU = false,
  });

  bool get canRun =>
      !isCompleted &&
      !isFailed &&
      !isRunning &&
      dependencies.every((dep) => dep.isCompleted);
}
