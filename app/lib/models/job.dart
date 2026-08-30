// ignore_for_file: prefer_initializing_formals

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
  Map<String, dynamic> metadata;

  Job({
    required this.id,
    required this.providerId,
    required this.type,
    JobStatus status = JobStatus.pending,
    this.progress = 0,
    this.result,
    Map<String, dynamic>? metadata,
  }) : _status = status,
       metadata = metadata ?? <String, dynamic>{};

  /// State Machine: enforces valid transitions between job states.
  bool transitionTo(JobStatus newStatus) {
    if (_status == newStatus) return true; // No-op is allowed

    bool isValid = false;
    switch (_status) {
      case JobStatus.pending:
        isValid =
            newStatus == JobStatus.queued || newStatus == JobStatus.cancelled;
        break;
      case JobStatus.queued:
        isValid =
            newStatus == JobStatus.starting ||
            newStatus == JobStatus.running ||
            newStatus == JobStatus.cancelled;
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
      metadata: Map<String, dynamic>.from(json["metadata"] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "providerId": providerId,
      "type": type,
      "status": _status.name,
      "progress": progress,
      "result": result,
      "metadata": metadata,
    };
  }
}
