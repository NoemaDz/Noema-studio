import 'artifact.dart';

class GeneratedAudio {
  final int sceneId;
  final String? characterName;
  final String jobId;
  final String text;
  Artifact? artifact;
  String? localPath;

  GeneratedAudio({
    required this.sceneId,
    this.characterName,
    required this.jobId,
    required this.text,
    this.artifact,
    this.localPath,
  });

  factory GeneratedAudio.fromJson(Map<String, dynamic> json) {
    return GeneratedAudio(
      sceneId: json["sceneId"],
      characterName: json["characterName"],
      jobId: json["jobId"],
      text: json["text"],
      artifact: json["artifact"] != null
          ? Artifact.fromJson(json["artifact"])
          : null,
      localPath: json["localPath"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "characterName": characterName,
      "jobId": jobId,
      "text": text,
      "artifact": artifact?.toJson(),
      "localPath": localPath,
    };
  }
}
