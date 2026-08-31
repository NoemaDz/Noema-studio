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
}
