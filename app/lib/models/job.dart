enum JobStatus { pending, queued, running, completed, failed }

class Job {
  final String id;
  final String providerId;
  final String type;

  JobStatus status;

  double progress;

  String? result;

  Map<String, dynamic> metadata;

  Job({
    required this.id,
    required this.providerId,
    required this.type,
    this.status = JobStatus.pending,
    this.progress = 0,
    this.result,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? <String, dynamic>{};

  factory Job.fromJson(Map<String, dynamic> json) {
    JobStatus parseStatus(dynamic statusStr) {
      if (statusStr == null) return JobStatus.pending;
      try {
        return JobStatus.values.byName(statusStr.toString());
      } catch (_) {
        return JobStatus.pending;
      }
    }

    return Job(
      id: json["id"],
      providerId: json["providerId"] ?? 'unknown', // Fallback for old projects
      type: json["type"],
      status: parseStatus(json["status"]),
      progress: (json["progress"] as num?)?.toDouble() ?? 0.0,
      result: json["result"],
      metadata: Map<String, dynamic>.from(json["metadata"] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "providerId": providerId,
      "type": type,
      "status": status.name,
      "progress": progress,
      "result": result,
      "metadata": metadata,
    };
  }
}
