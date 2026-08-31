enum ToolResultStatus {
  success,
  recoverableFailure,
  fatalFailure,
}

class ArtifactReference {
  final String artifactId;
  final String type;

  ArtifactReference({required this.artifactId, required this.type});

  Map<String, dynamic> toJson() => {
    'artifactId': artifactId,
    'type': type,
  };
}

class JobReference {
  final String jobId;
  final String type;

  JobReference({required this.jobId, required this.type});

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'type': type,
  };
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
    if (artifacts != null) 'artifacts': artifacts!.map((a) => a.toJson()).toList(),
    if (jobs != null) 'jobs': jobs!.map((j) => j.toJson()).toList(),
  };
}
