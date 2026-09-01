import 'agent.dart';
import 'agent_planner.dart';
import 'models/agent_plan.dart';
import 'models/agent_session.dart';
import 'models/agent_action.dart';

import 'models/permission_outcome.dart';

class LlmAgent extends Agent {
  final AgentPlanner planner;

  // Provide a callback or mechanism for requesting permissions from the UI
  final Future<PermissionOutcome> Function(AgentAction action)
  onPermissionRequested;

  LlmAgent({
    required super.toolbox,
    required super.permissionPolicy,
    required this.planner,
    required this.onPermissionRequested,
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    // Uses the lightweight async LLM client to parse goal into a plan
    return planner.formulatePlan(session);
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) {
    return onPermissionRequested(action);
  }
}
