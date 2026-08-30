import 'provider.dart';
import '../../models/job.dart' as noema_job;
import '../contracts/execution_request.dart' as noema_contracts;
import '../contracts/execution_result.dart' as noema_contracts;

abstract class DocumentIngestionProvider extends Provider {
  /// The file extensions this provider can handle (e.g., ['pdf'], ['txt'])
  List<String> get supportedExtensions;

  /// Reads the text content from the file at the given path
  Future<String> readText(String filePath);

  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async {
    throw UnimplementedError(
      "Document ingestion does not use the async job execution contract",
    );
  }

  @override
  Future<noema_contracts.ExecutionResult> getResult(String jobId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelJob(String jobId) async {}
}
