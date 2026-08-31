import 'models/agent_plan.dart';
import 'models/agent_action.dart';
import 'models/agent_session.dart';
import 'agent_toolbox.dart';
import 'permissions/permission_policy.dart';

abstract class Agent {
  final AgentToolbox toolbox;
  final PermissionPolicy permissionPolicy;

  Agent({required this.toolbox, required this.permissionPolicy});

  Future<AgentPlan> formulatePlan(AgentSession session);

  Future<void> executePlan(AgentSession session, AgentPlan plan) async {
    for (final step in plan.steps) {
      final action = step.action;
      dynamic result;

      try {
        result = await toolbox.executeAction(action);
      } on UnauthorizedException {
        final granted = await requestPermission(action);
        if (!granted) {
          throw Exception('Permission denied for action: ${action.toolId}');
        }
        // Retry after permission is granted
        result = await toolbox.executeAction(action);
      }

      session.executedActions.add(action);
      session.results[step.id] = result;

      permissionPolicy.onActionComplete(action.toolId);
    }
    permissionPolicy.onTaskComplete();
  }

  /// Hook for human-in-the-loop authorization
  Future<bool> requestPermission(AgentAction action);
}
