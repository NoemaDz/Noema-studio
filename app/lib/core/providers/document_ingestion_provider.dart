import 'provider.dart';
import '../../models/job.dart' as noema_job;
import '../contracts/execution_request.dart' as noema_contracts;
import '../contracts/execution_result.dart' as noema_contracts;

import 'package:uuid/uuid.dart';

abstract class DocumentIngestionProvider extends Provider {
  final Map<String, noema_contracts.ExecutionResult> _results = {};

  /// The file extensions this provider can handle (e.g., ['pdf'], ['txt'])
  List<String> get supportedExtensions;

  /// Reads the text content from the file at the given path
  Future<String> readText(String filePath);

  @override
  Future<noema_job.Job> execute(
    noema_contracts.ExecutionRequest request,
  ) async {
    final filePath = request.parameters['file_path'] as String?;
    if (filePath == null) {
      throw Exception("Missing 'file_path' parameter for document ingestion");
    }

    final jobId = request.jobId ?? const Uuid().v4();
    final job = noema_job.Job(
      id: jobId,
      providerId: id,
      type: "ingestion",
      status: noema_job.JobStatus.running,
    );

    // Run ingestion asynchronously
    Future.microtask(() async {
      try {
        final text = await readText(filePath);
        _results[jobId] = noema_contracts.ExecutionResult.success(
          textOutput: text,
        );
        job.result = "Ingestion complete";
        job.progress = 1.0;
        job.transitionTo(noema_job.JobStatus.completed);
      } catch (e) {
        _results[jobId] = noema_contracts.ExecutionResult.failure(
          noema_job.JobError(code: 'ingestion_failed', message: e.toString()),
        );
        job.result = "Ingestion failed: $e";
        job.transitionTo(noema_job.JobStatus.failed);
      }
    });

    return job;
  }

  @override
  Future<noema_contracts.ExecutionResult> getResult(String jobId) async {
    final result = _results[jobId];
    if (result != null) {
      return result;
    }
    return noema_contracts.ExecutionResult.failure(
      noema_job.JobError(
        code: 'not_found',
        message: 'Result not found for job $jobId',
      ),
    );
  }

  @override
  Future<void> cancelJob(String jobId) async {
    // Document ingestion is generally too fast to cancel, so we no-op here.
    return;
  }
}
