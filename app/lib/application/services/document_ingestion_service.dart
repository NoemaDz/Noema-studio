import 'package:noema_studio/core/providers/provider_registry.dart';
import 'package:noema_studio/core/contracts/execution_request.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/providers/document_ingestion_provider.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:path/path.dart' as p;

class DocumentIngestionService {
  final ProviderRegistry registry;
  final JobManager jobManager;

  DocumentIngestionService(this.registry, this.jobManager);

  Future<String> importDocument(String filePath) async {
    final extension = p.extension(filePath).toLowerCase().replaceAll('.', '');

    DocumentIngestionProvider? provider;
    for (final p in registry.all) {
      if (p is DocumentIngestionProvider &&
          p.available &&
          p.supportedExtensions.contains(extension)) {
        provider = p;
        break;
      }
    }

    if (provider == null) {
      throw Exception("No ingestion provider found for .$extension files");
    }

    final request = ExecutionRequest(
      capability: CapabilityType.llm,
      input: '',
      parameters: {'file_path': filePath},
    );
    final job = await provider.execute(request);
    jobManager.add(job);

    await jobManager.waitForCompletion(job.id);

    final result = await provider.getResult(job.id);
    if (result.isSuccess) {
      return result.textOutput ?? "";
    } else {
      throw Exception(result.error?.message ?? "Ingestion failed");
    }
  }
}
