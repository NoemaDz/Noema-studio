import 'async_provider.dart';
import 'dart:async';
import '../../models/job.dart' as noema_job;
import '../contracts/execution_request.dart' as noema_contracts;
import '../contracts/execution_result.dart' as noema_contracts;

import 'package:uuid/uuid.dart';

abstract class DocumentIngestionProvider extends AsyncProvider {
  final Map<String, noema_contracts.ExecutionResult> _results = {};
  final Map<String, noema_job.JobStatusUpdate> _updates = {};
  final Map<String, Completer<noema_contracts.ExecutionResult>>
  _resultCompleters = {};

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

    _resultCompleters[jobId] = Completer<noema_contracts.ExecutionResult>();
    _updates[jobId] = noema_job.JobStatusUpdate(
      status: noema_job.JobStatus.running,
    );

    // Run ingestion asynchronously
    Future.microtask(() async {
      try {
        final text = await readText(filePath);
        final execResult = noema_contracts.ExecutionResult.success(
          textOutput: text,
        );
        _results[jobId] = execResult;
        _updates[jobId] = noema_job.JobStatusUpdate(
          status: noema_job.JobStatus.completed,
          progress: 1.0,
          result: "Ingestion complete",
        );
        _resultCompleters[jobId]?.complete(execResult);
      } catch (e) {
        final error = noema_job.JobError(
          code: 'ingestion_failed',
          message: e.toString(),
        );
        final execResult = noema_contracts.ExecutionResult.failure(error);
        _results[jobId] = execResult;
        _updates[jobId] = noema_job.JobStatusUpdate(
          status: noema_job.JobStatus.failed,
          error: error,
        );
        _resultCompleters[jobId]?.complete(execResult);
      }
    });

    return job;
  }

  @override
  Future<noema_job.JobStatusUpdate> updateJobStatus(noema_job.Job job) async {
    return _updates[job.id] ??
        noema_job.JobStatusUpdate(
          status: noema_job.JobStatus.failed,
          error: noema_job.JobError(
            code: 'not_found',
            message: 'Job not found',
          ),
        );
  }

  @override
  Future<noema_contracts.ExecutionResult> getResult(String jobId) async {
    if (_results.containsKey(jobId)) {
      return _results[jobId]!;
    }
    if (_resultCompleters.containsKey(jobId)) {
      return await _resultCompleters[jobId]!.future;
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
