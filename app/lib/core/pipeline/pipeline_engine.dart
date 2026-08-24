import 'dart:async';
import 'task_node.dart';
import '../cancellation_token.dart';

class PipelineEngine {
  final int maxConcurrentTasks;

  PipelineEngine({this.maxConcurrentTasks = 2});

  void validateGraph(List<TaskNode> tasks) {
    final ids = <String>{};
    for (final task in tasks) {
      if (ids.contains(task.id)) {
        throw Exception("Duplicate Task ID: \${task.id}");
      }
      ids.add(task.id);
    }

    // Check for missing dependencies
    for (final task in tasks) {
      for (final dep in task.dependencies) {
        if (!ids.contains(dep.id)) {
          throw Exception("Missing dependency \${dep.id} for task \${task.id}");
        }
      }
    }

    // Check for cycles (DFS)
    final visited = <String, bool>{};
    final recStack = <String, bool>{};

    bool isCyclic(TaskNode node) {
      if (recStack[node.id] == true) return true;
      if (visited[node.id] == true) return false;

      visited[node.id] = true;
      recStack[node.id] = true;

      for (final dep in node.dependencies) {
        if (isCyclic(dep)) return true;
      }

      recStack[node.id] = false;
      return false;
    }

    for (final task in tasks) {
      if (isCyclic(task)) {
        throw Exception("Cyclic dependency detected in Pipeline DAG involving \${task.id}");
      }
    }
  }

  Future<void> run(
    List<TaskNode> tasks, {
    void Function(TaskNode)? onTaskUpdate,
    CancellationToken? cancellationToken,
  }) async {
    validateGraph(tasks);
    
    final completer = Completer<void>();
    int runningTasksCount = 0;
    bool hasFailedTask = false;

    void checkAndRun() {
      if (cancellationToken?.isCancelled == true) {
        if (!completer.isCompleted) completer.completeError(CancelledException());
        return;
      }

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
        task
            .execute()
            .then((_) {
              task.isCompleted = true;
              task.isRunning = false;
              runningTasksCount--;
              onTaskUpdate?.call(task);
              checkAndRun(); // Trigger next tasks
            })
            .catchError((error) {
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
