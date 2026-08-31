import '../../core/noema_project.dart';
import 'agent_plan.dart';
import 'agent_action.dart';

class AgentSession {
  final NoemaProject currentProject;
  final String currentGoal;
  AgentPlan? currentPlan;
  final List<AgentAction> executedActions = [];
  final Map<String, dynamic> results = {};

  AgentSession({
    required this.currentProject,
    required this.currentGoal,
    this.currentPlan,
  });
}
