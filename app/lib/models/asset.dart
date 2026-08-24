import 'asset_type.dart';

class Asset {
  final String id;

  final String path;

  final AssetType type;

  const Asset({required this.id, required this.path, required this.type});

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json["id"],
      path: json["path"],
      type: AssetType.values.byName(json["type"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "path": path, "type": type.name};
  }
}
