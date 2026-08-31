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
  waitingForJobs,
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
  bool isLoopRunning = false;

  AgentSession({
    required this.currentProject,
    required this.currentGoal,
    this.currentPlan,
  });

  Map<String, dynamic> toJson() => {
    'currentGoal': currentGoal,
    if (currentPlan != null) 'currentPlan': currentPlan!.toJson(),
    'executedActions': executedActions.map((a) => a.toJson()).toList(),
    'results': results,
    'deniedTools': deniedTools,
    'observations': observations.map((o) => o.toJson()).toList(),
    'state': state.name,
  };

  factory AgentSession.fromJson(Map<String, dynamic> json, NoemaProject project) {
    final session = AgentSession(
      currentProject: project,
      currentGoal: json['currentGoal'] as String,
      currentPlan: json['currentPlan'] != null
          ? AgentPlan.fromJson(json['currentPlan'] as Map<String, dynamic>)
          : null,
    );

    session.state = AgentSessionState.values.byName(json['state'] as String);
    
    if (json['executedActions'] != null) {
      session.executedActions.addAll(
        (json['executedActions'] as List).map((a) => AgentAction.fromJson(a as Map<String, dynamic>)),
      );
    }
    if (json['results'] != null) {
      session.results.addAll(Map<String, dynamic>.from(json['results'] as Map));
    }
    if (json['deniedTools'] != null) {
      session.deniedTools.addAll(
        (json['deniedTools'] as List).map((dt) => Map<String, String>.from(dt as Map)),
      );
    }
    if (json['observations'] != null) {
      session.observations.addAll(
        (json['observations'] as List).map((o) => AgentObservation.fromJson(o as Map<String, dynamic>)),
      );
    }

    return session;
  }
}
