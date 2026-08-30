import 'artifact.dart';

class GeneratedVideo {
  final int sceneId;
  final String jobId;
  final String sourceImagePath;
  Artifact? artifact;

  GeneratedVideo({
    required this.sceneId,
    required this.jobId,
    required this.sourceImagePath,
    this.artifact,
  });

  factory GeneratedVideo.fromJson(Map<String, dynamic> json) {
    return GeneratedVideo(
      sceneId: json["sceneId"],
      jobId: json["jobId"],
      sourceImagePath: json["sourceImagePath"] ?? '',
      artifact: json["artifact"] != null
          ? Artifact.fromJson(json["artifact"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "jobId": jobId,
      "sourceImagePath": sourceImagePath,
      "artifact": artifact?.toJson(),
    };
  }
}
