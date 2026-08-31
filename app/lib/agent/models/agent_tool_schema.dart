import '../permissions/tool_risk_level.dart';

class AgentToolSchema {
  final String id;
  final String description;
  final Map<String, dynamic> parameters;
  final ToolRiskLevel riskLevel;

  AgentToolSchema({
    required this.id,
    required this.description,
    required this.parameters,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'parameters': parameters,
    'riskLevel': riskLevel.name,
  };
}
