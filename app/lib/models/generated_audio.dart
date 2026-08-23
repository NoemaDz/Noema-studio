import 'asset.dart';

class GeneratedAudio {
  final int sceneId;
  final String? characterName;
  final String jobId;
  final String text;
  Asset? asset;
  String? localPath;

  GeneratedAudio({
    required this.sceneId,
    this.characterName,
    required this.jobId,
    required this.text,
    this.asset,
    this.localPath,
  });

  factory GeneratedAudio.fromJson(Map<String, dynamic> json) {
    return GeneratedAudio(
      sceneId: json["sceneId"],
      characterName: json["characterName"],
      jobId: json["jobId"],
      text: json["text"],
      asset: json["asset"] != null ? Asset.fromJson(json["asset"]) : null,
      localPath: json["localPath"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "characterName": characterName,
      "jobId": jobId,
      "text": text,
      "asset": asset?.toJson(),
      "localPath": localPath,
    };
  }
}
