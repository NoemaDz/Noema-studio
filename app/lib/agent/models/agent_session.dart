import '../../core/noema_project.dart';
import 'agent_plan.dart';
import 'agent_action.dart';
import 'agent_observation.dart';

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
  final List<AgentObservation> observations = [];
  
  AgentSessionState state = AgentSessionState.initial;

  AgentSession({
    required this.currentProject,
    required this.currentGoal,
    this.currentPlan,
  });
}
