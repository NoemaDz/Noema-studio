import 'dart:io';

class AssetStorage {
  final Directory root;

  AssetStorage({Directory? root})
    : root = root ?? Directory("assets/generated");

  Future<void> initialize() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
  }

  File imageFile(String filename) {
    return File("${root.path}/$filename");
  }
}
