import '../permissions/tool_risk_level.dart';

abstract class AgentAction {
  final String toolId;
  final ToolRiskLevel riskLevel;
  final Map<String, dynamic> arguments;

  AgentAction({
    required this.toolId,
    required this.riskLevel,
    this.arguments = const {},
  });
}
