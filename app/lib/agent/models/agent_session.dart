import '../../core/noema_project.dart';
import 'agent_plan.dart';
import 'agent_action.dart';

enum AgentSessionState {
  initial,
  running,
  waitingForPermission,
  replanning,
  completed,
  stopped,
  failed,
  iterationLimitReached,
}

class AgentSession {
  final NoemaProject currentProject;
  final String currentGoal;
  AgentPlan? currentPlan;
  final List<AgentAction> executedActions = [];
  final Map<String, dynamic> results = {};
  
  final List<Map<String, String>> deniedTools = [];
  final List<String> observationHistory = [];
  
  AgentSessionState state = AgentSessionState.initial;

  AgentSession({
    required this.currentProject,
    required this.currentGoal,
    this.currentPlan,
  });
}
