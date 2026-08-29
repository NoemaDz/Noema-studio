import 'asset.dart';

class GeneratedImage {
  final int sceneId;

  String jobId; // mutable: updated on IPAdapter fallback re-submission

  final String prompt;

  Asset? asset;

  GeneratedImage({
    required this.sceneId,
    required this.jobId,
    required this.prompt,
    this.asset,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      sceneId: json["sceneId"],
      jobId: json["jobId"],
      prompt: json["prompt"],
      asset: json["asset"] != null ? Asset.fromJson(json["asset"]) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "sceneId": sceneId,
      "jobId": jobId,
      "prompt": prompt,
      "asset": asset?.toJson(),
    };
  }
}
