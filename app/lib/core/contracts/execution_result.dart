import '../../models/artifact.dart';
import '../../models/job.dart';

class ExecutionResult {
  final bool isSuccess;
  final Artifact? artifact;
  final String? textOutput;
  final JobError? error;

  ExecutionResult.success({this.artifact, this.textOutput})
    : isSuccess = true,
      error = null;

  ExecutionResult.failure(this.error)
    : isSuccess = false,
      artifact = null,
      textOutput = null;
}
