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

  factory AgentObservation.fromJson(Map<String, dynamic> json) {
    return AgentObservation(
      stepId: json['stepId'] as String,
      toolId: json['toolId'] as String,
      result: ToolResult.fromJson(json['result'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
