import '../permissions/tool_risk_level.dart';

class AgentToolSchema {
  final String id;
  final String description;
  final Map<String, dynamic> parameters;
  final List<String> requiredParameters;
  final ToolRiskLevel riskLevel;

  AgentToolSchema({
    required this.id,
    required this.description,
    required this.parameters,
    List<String>? requiredParameters,
    required this.riskLevel,
  }) : requiredParameters = requiredParameters ?? parameters.keys.toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'parameters': parameters,
    'requiredParameters': requiredParameters,
    'riskLevel': riskLevel.name,
  };
}
