import 'agent_step.dart';

class AgentPlan {
  final String goal;
  final List<AgentStep> steps;

  AgentPlan({required this.goal, required this.steps});
}
