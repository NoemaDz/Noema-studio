// ignore_for_file: prefer_initializing_formals

class JobError {
  final String code;
  final String message;
  final dynamic details;

  JobError({required this.code, required this.message, this.details});

  factory JobError.fromJson(Map<String, dynamic> json) {
    return JobError(
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}

class JobStatusUpdate {
  final JobStatus status;
  final double? progress;
  final String? result;
  final JobError? error;

  JobStatusUpdate({
    required this.status,
    this.progress,
    this.result,
    this.error,
  });
}

enum JobStatus {
  pending,
  queued,
  starting,
  running,
  retrying,
  cancelling,
  cancelled,
  completed,
  failed,
}

class Job {
  final String id;
  final String providerId;
  final String type;

  JobStatus _status;
  JobStatus get status => _status;

  double progress;
  String? result;
  JobError? error;
  Map<String, dynamic> metadata;

  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  Job({
    required this.id,
    required this.providerId,
    required this.type,
    JobStatus status = JobStatus.pending,
    this.progress = 0,
    this.result,
    this.error,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : _status = status,
       createdAt = createdAt ?? DateTime.now(),
       metadata = metadata ?? <String, dynamic>{};

  /// State Machine: enforces valid transitions between job states.
  bool transitionTo(JobStatus newStatus) {
    if (_status == newStatus) return true; // No-op is allowed

    bool isValid = false;
    switch (_status) {
      case JobStatus.pending:
        isValid =
            newStatus == JobStatus.queued ||
            newStatus == JobStatus.cancelled ||
            newStatus == JobStatus.cancelling;
        break;
      case JobStatus.queued:
        isValid =
            newStatus == JobStatus.starting ||
            newStatus == JobStatus.running ||
            newStatus == JobStatus.cancelled ||
            newStatus == JobStatus.cancelling;
        break;
      case JobStatus.starting:
        isValid =
            newStatus == JobStatus.running ||
            newStatus == JobStatus.failed ||
            newStatus == JobStatus.cancelling;
        break;
      case JobStatus.running:
        isValid =
            newStatus == JobStatus.completed ||
            newStatus == JobStatus.failed ||
            newStatus == JobStatus.cancelling ||
            newStatus == JobStatus.retrying;
        break;
      case JobStatus.retrying:
        isValid =
            newStatus == JobStatus.running ||
            newStatus == JobStatus.failed ||
            newStatus == JobStatus.cancelling;
        break;
      case JobStatus.cancelling:
        isValid =
            newStatus == JobStatus.cancelled || newStatus == JobStatus.failed;
        break;
      case JobStatus.completed:
      case JobStatus.failed:
      case JobStatus.cancelled:
        // Terminal states cannot transition to anything else
        isValid = false;
        break;
    }

    if (isValid) {
      _status = newStatus;

      // Update timestamps automatically based on state transition
      if (newStatus == JobStatus.running && startedAt == null) {
        startedAt = DateTime.now();
      } else if (newStatus == JobStatus.completed ||
          newStatus == JobStatus.failed ||
          newStatus == JobStatus.cancelled) {
        completedAt ??= DateTime.now();
      }

      return true;
    } else {
      // Return false to indicate illegal transition instead of throwing to prevent crashing the UI/polling loops
      return false;
    }
  }

  // To allow forced overrides in very specific cases (e.g., deserialization)
  void forceStatus(JobStatus newStatus) {
    _status = newStatus;
  }

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
      error: json["error"] != null ? JobError.fromJson(json["error"]) : null,
      metadata: Map<String, dynamic>.from(json["metadata"] ?? {}),
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : null,
      startedAt: json["startedAt"] != null
          ? DateTime.parse(json["startedAt"])
          : null,
      completedAt: json["completedAt"] != null
          ? DateTime.parse(json["completedAt"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "providerId": providerId,
      "type": type,
      "status": _status.name,
      "progress": progress,
      if (result != null) "result": result,
      if (error != null) "error": error!.toJson(),
      "metadata": metadata,
      "createdAt": createdAt.toIso8601String(),
      if (startedAt != null) "startedAt": startedAt!.toIso8601String(),
      if (completedAt != null) "completedAt": completedAt!.toIso8601String(),
    };
  }
}
