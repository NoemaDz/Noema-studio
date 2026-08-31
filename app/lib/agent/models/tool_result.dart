enum ToolResultStatus {
  success,
  recoverableFailure,
  fatalFailure,
}

class ToolArtifact {
  final String artifactId;
  final String type;

  ToolArtifact({required this.artifactId, required this.type});

  Map<String, dynamic> toJson() => {
    'artifactId': artifactId,
    'type': type,
  };
}

class ToolResult {
  final String toolId;
  final ToolResultStatus status;
  final Map<String, dynamic>? data;
  final String? error;
  final List<ToolArtifact>? artifacts;

  ToolResult({
    required this.toolId,
    required this.status,
    this.data,
    this.error,
    this.artifacts,
  });

  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'status': status.name,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
    if (artifacts != null) 'artifacts': artifacts!.map((a) => a.toJson()).toList(),
  };
}
