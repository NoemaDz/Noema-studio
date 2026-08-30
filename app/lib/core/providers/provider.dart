import '../capabilities/capability.dart';
import '../../models/job.dart';
import '../contracts/execution_request.dart';
import '../contracts/execution_result.dart';

abstract class Provider {
  String get id;
  String get name;
  bool get available;

  Set<CapabilityType> get capabilities;
  HardwareRequirements get hardwareRequirements;

  /// Starts the execution and returns a Job for tracking.
  Future<Job> execute(ExecutionRequest request);

  /// Retrieves the unified result of the execution.
  Future<ExecutionResult> getResult(String jobId);

  /// Cancels a running job.
  Future<void> cancelJob(String jobId);
}
