import 'agent_action.dart';

class AgentStep {
  final String id;
  final String description;
  final AgentAction action;

  AgentStep({
    required this.id,
    required this.description,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'action': action.toJson(),
  };

  factory AgentStep.fromJson(Map<String, dynamic> json) {
    return AgentStep(
      id: json['id'] as String,
      description: json['description'] as String,
      action: AgentAction.fromJson(json['action'] as Map<String, dynamic>),
    );
  }
}
