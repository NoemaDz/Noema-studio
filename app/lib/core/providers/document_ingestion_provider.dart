import 'provider.dart';

abstract class DocumentIngestionProvider extends Provider {
  /// The file extensions this provider can handle (e.g., ['pdf'], ['txt'])
  List<String> get supportedExtensions;

  /// Reads the text content from the file at the given path
  Future<String> readText(String filePath);
}
