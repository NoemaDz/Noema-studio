import 'dart:async';
import 'task_node.dart';

class PipelineEngine {
  final int maxConcurrentTasks;

  PipelineEngine({this.maxConcurrentTasks = 2});

  Future<void> run(List<TaskNode> tasks, {void Function(TaskNode)? onTaskUpdate}) async {
    final completer = Completer<void>();
    int runningTasksCount = 0;
    bool hasFailedTask = false;

    void checkAndRun() {
      if (hasFailedTask) return; // Stop if any task failed

      // Check if all are done
      if (tasks.every((t) => t.isCompleted)) {
        if (!completer.isCompleted) completer.complete();
        return;
      }

      // Find tasks that can run
      final runnableTasks = tasks.where((t) => t.canRun).toList();

      for (var task in runnableTasks) {
        if (runningTasksCount >= maxConcurrentTasks) break;

        task.isRunning = true;
        runningTasksCount++;
        onTaskUpdate?.call(task);

        // Execute asynchronously
        task.execute().then((_) {
          task.isCompleted = true;
          task.isRunning = false;
          runningTasksCount--;
          onTaskUpdate?.call(task);
          checkAndRun(); // Trigger next tasks
        }).catchError((error) {
          task.isFailed = true;
          task.isRunning = false;
          hasFailedTask = true;
          runningTasksCount--;
          onTaskUpdate?.call(task);
          if (!completer.isCompleted) completer.completeError(error);
        });
      }
    }

    checkAndRun();
    return completer.future;
  }
}
