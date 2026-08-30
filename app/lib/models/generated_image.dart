import 'artifact.dart';

class GeneratedImage {
  final int sceneId;

  String jobId; // mutable: updated on IPAdapter fallback re-submission

  final String prompt;

  Artifact? artifact;

  GeneratedImage({
    required this.sceneId,
    required this.jobId,
    required this.prompt,
    this.artifact,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      sceneId: json["sceneId"],
      jobId: json["jobId"],
      prompt: json["prompt"],
      artifact: json["artifact"] != null
          ? Artifact.fromJson(json["artifact"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "jobId": jobId,
      "prompt": prompt,
      "artifact": artifact?.toJson(),
    };
  }
}
