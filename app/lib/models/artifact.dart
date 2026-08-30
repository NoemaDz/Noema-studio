import 'artifact_type.dart';

class Artifact {
  final String id;

  final String path;

  final ArtifactType type;

  const Artifact({required this.id, required this.path, required this.type});

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json["id"],
      path: json["path"],
      type: ArtifactType.values.byName(json["type"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "path": path, "type": type.name};
  }
}
