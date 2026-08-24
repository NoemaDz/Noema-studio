import '../noema_project.dart';
import 'pipeline_registry.dart';
import 'task_node.dart';
import 'pipeline_engine.dart';

class ProjectPipeline {
  final PipelineRegistry registry;
  final PipelineEngine engine;

  ProjectPipeline({
    required this.registry,
    PipelineEngine? engine,
  }) : engine = engine ?? PipelineEngine(maxConcurrentTasks: 2);

  Future<NoemaProject> generate(NoemaProject project, {void Function(String)? onUpdate}) async {
    final tasks = <TaskNode>[];
    TaskNode? previousTask;

    // Convert old stages to TaskNodes. For now, they run sequentially.
    // In Phase 3, we will break these down into per-scene concurrent tasks!
    for (final stage in registry.stages) {
      final task = TaskNode(
        id: stage.runtimeType.toString(),
        name: stage.runtimeType.toString(),
        execute: () => stage.run(project),
        dependencies: previousTask != null ? [previousTask] : [],
      );
      tasks.add(task);
      previousTask = task;
    }

    await engine.run(tasks, onTaskUpdate: (task) {
      final status = "Pipeline: Task ${task.name} is ${task.isCompleted ? 'completed' : task.isFailed ? 'failed' : task.isRunning ? 'running' : 'waiting'}";
      onUpdate?.call(status);
      // ignore: avoid_print
      print(status);
    });

    return project;
  }
}