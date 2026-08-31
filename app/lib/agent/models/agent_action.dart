import '../permissions/tool_risk_level.dart';

class AgentAction {
  final String toolId;
  final ToolRiskLevel riskLevel;
  final Map<String, dynamic> arguments;

  AgentAction({
    required this.toolId,
    required this.riskLevel,
    this.arguments = const {},
  });

  Map<String, dynamic> toJson() => {
    'toolId': toolId,
    'riskLevel': riskLevel.name,
    'arguments': arguments,
  };

  factory AgentAction.fromJson(Map<String, dynamic> json) {
    return AgentAction(
      toolId: json['toolId'] as String,
      riskLevel: ToolRiskLevel.values.byName(json['riskLevel'] as String),
      arguments: Map<String, dynamic>.from(json['arguments'] as Map),
    );
  }
}
