enum ToolResultStatus { success, recoverableFailure, fatalFailure }

class ArtifactReference {
  final String artifactId;
  final String type;

  ArtifactReference({required this.artifactId, required this.type});

  Map<String, dynamic> toJson() => {'artifactId': artifactId, 'type': type};

  factory ArtifactReference.fromJson(Map<String, dynamic> json) {
    return ArtifactReference(
      artifactId: json['artifactId'] as String,
      type: json['type'] as String,
    );
  }
}

class JobReference {
  final String jobId;
  final String type;

  JobReference({required this.jobId, required this.type});

  Map<String, dynamic> toJson() => {'jobId': jobId, 'type': type};

  factory JobReference.fromJson(Map<String, dynamic> json) {
    return JobReference(
      jobId: json['jobId'] as String,
      type: json['type'] as String,
    );
  }
}

class ToolResult {
  final String toolId;
  final ToolResultStatus status;
  final Map<String, dynamic>? data;
  final String? error;
  final List<ArtifactReference>? artifacts;
  final List<JobReference>? jobs;

  ToolResult({
    required this.toolId,
    required this.status,
    this.data,
    this.error,
    this.artifacts,
    this.jobs,
  });

  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'status': status.name,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
    if (artifacts != null)
      'artifacts': artifacts!.map((a) => a.toJson()).toList(),
    if (jobs != null) 'jobs': jobs!.map((j) => j.toJson()).toList(),
  };

  factory ToolResult.fromJson(Map<String, dynamic> json) {
    return ToolResult(
      toolId: json['toolId'] as String,
      status: ToolResultStatus.values.byName(json['status'] as String),
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      error: json['error'] as String?,
      artifacts: json['artifacts'] != null
          ? (json['artifacts'] as List)
                .map(
                  (a) => ArtifactReference.fromJson(a as Map<String, dynamic>),
                )
                .toList()
          : null,
      jobs: json['jobs'] != null
          ? (json['jobs'] as List)
                .map((j) => JobReference.fromJson(j as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}
