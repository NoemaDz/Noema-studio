import 'asset.dart';

class GeneratedVideo {
  final int sceneId;
  final String jobId;
  final String sourceImagePath;
  Asset? asset;

  GeneratedVideo({
    required this.sceneId,
    required this.jobId,
    required this.sourceImagePath,
    this.asset,
  });

  factory GeneratedVideo.fromJson(Map<String, dynamic> json) {
    return GeneratedVideo(
      sceneId: json["sceneId"],
      jobId: json["jobId"],
      sourceImagePath: json["sourceImagePath"] ?? '',
      asset: json["asset"] != null ? Asset.fromJson(json["asset"]) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "jobId": jobId,
      "sourceImagePath": sourceImagePath,
      "asset": asset?.toJson(),
    };
  }
}
