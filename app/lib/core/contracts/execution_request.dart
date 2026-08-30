import '../capabilities/capability.dart';

class ExecutionRequest {
  final CapabilityType capability;
  final String input;
  final Map<String, dynamic> parameters;
  final String? projectContextId;
  final String? jobId;

  ExecutionRequest({
    required this.capability,
    required this.input,
    this.parameters = const {},
    this.projectContextId,
    this.jobId,
  });
}
