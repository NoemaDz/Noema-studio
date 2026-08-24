import 'task.dart';
import 'task_status.dart';

class ProjectTask {
  final TaskType type;

  TaskStatus status;

  double progress;

  String? message;

  DateTime? startedAt;

  DateTime? finishedAt;

  ProjectTask({
    required this.type,
    this.status = TaskStatus.pending,
    this.progress = 0,
    this.message,
    this.startedAt,
    this.finishedAt,
  });

  bool get isCompleted {
    return status == TaskStatus.completed;
  }

  factory ProjectTask.fromJson(Map<String, dynamic> json) {
    return ProjectTask(
      type: TaskType.values.byName(json["type"]),
      status: TaskStatus.values.byName(json["status"]),
      progress: (json["progress"] as num).toDouble(),
      message: json["message"],
      startedAt: json["startedAt"] != null
          ? DateTime.parse(json["startedAt"])
          : null,
      finishedAt: json["finishedAt"] != null
          ? DateTime.parse(json["finishedAt"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "type": type.name,
      "status": status.name,
      "progress": progress,
      "message": message,
      "startedAt": startedAt?.toIso8601String(),
      "finishedAt": finishedAt?.toIso8601String(),
    };
  }
}
