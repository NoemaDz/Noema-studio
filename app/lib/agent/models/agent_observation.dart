import 'tool_result.dart';

class AgentObservation {
  final String stepId;
  final String toolId;
  final ToolResult result;
  final DateTime timestamp;

  AgentObservation({
    required this.stepId,
    required this.toolId,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'toolId': toolId,
    'result': result.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };
}
