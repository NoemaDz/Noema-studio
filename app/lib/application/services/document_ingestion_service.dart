import '../../core/providers/provider_registry.dart';
import '../../core/providers/document_ingestion_provider.dart';
import 'package:path/path.dart' as p;

class DocumentIngestionService {
  final ProviderRegistry registry;

  DocumentIngestionService(this.registry);

  Future<String> importDocument(String filePath) async {
    final extension = p.extension(filePath).toLowerCase().replaceAll('.', '');

    // Find a provider that supports this extension
    for (final provider in registry.all) {
      if (provider is DocumentIngestionProvider && provider.available) {
        if (provider.supportedExtensions.contains(extension)) {
          return await provider.readText(filePath);
        }
      }
    }

    throw Exception("No ingestion provider found for extension: .$extension");
  }
}
