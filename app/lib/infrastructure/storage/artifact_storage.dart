import 'dart:io';

class ArtifactStorage {
  final Directory root;

  ArtifactStorage({Directory? root})
    : root = root ?? Directory("artifacts/generated");

  Future<void> initialize() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
  }

  File imageFile(String filename) {
    return File("${root.path}/$filename");
  }
}
