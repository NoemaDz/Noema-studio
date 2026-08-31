import 'models/agent_plan.dart';
import 'models/agent_action.dart';
import 'models/agent_session.dart';
import 'models/permission_outcome.dart';
import 'agent_toolbox.dart';
import 'permissions/permission_policy.dart';

class TaskStoppedException implements Exception {
  final String message;
  TaskStoppedException(this.message);
  @override
  String toString() => 'TaskStoppedException: $message';
}

abstract class Agent {
  final AgentToolbox toolbox;
  final PermissionPolicy permissionPolicy;

  Agent({required this.toolbox, required this.permissionPolicy});

  Future<AgentPlan> formulatePlan(AgentSession session);

  Future<void> run(AgentSession session, {int maxIterations = 5}) async {
    session.state = AgentSessionState.running;
    
    for (int i = 0; i < maxIterations; i++) {
      if (session.state == AgentSessionState.stopped || session.state == AgentSessionState.completed) {
        break;
      }
      if (session.state == AgentSessionState.failed) {
        break;
      }
      
      session.state = AgentSessionState.running;
      session.observationHistory.add('Iteration ${i + 1} started.');
      
      final plan = await formulatePlan(session);
      session.currentPlan = plan;
      
      if (plan.steps.isEmpty) {
        session.observationHistory.add('Plan formulated with 0 steps. Assuming stuck.');
        session.state = AgentSessionState.failed;
        break;
      }

      final completed = await executePlan(session, plan);
      if (completed) {
        session.state = AgentSessionState.completed;
        session.observationHistory.add('Task marked as complete by Agent.');
        permissionPolicy.onTaskComplete();
        break;
      }
    }
    
    if (session.state == AgentSessionState.running || session.state == AgentSessionState.replanning) {
      session.state = AgentSessionState.iterationLimitReached;
    }
  }

  /// Returns true if task_complete was called and the loop should terminate.
  Future<bool> executePlan(AgentSession session, AgentPlan plan) async {
    for (final step in plan.steps) {
      final action = step.action;
      dynamic result;

      try {
        result = await toolbox.executeAction(session, action);
        
        if (action.toolId == 'task_complete') {
          return true; // Goal achieved
        }
        
        session.observationHistory.add('Tool ${action.toolId} result: $result');
      } on UnauthorizedException {
        session.state = AgentSessionState.waitingForPermission;
        final outcome = await requestPermission(action);
        
        if (outcome == PermissionOutcome.allow) {
          // Granted, try again immediately
          session.state = AgentSessionState.running;
          result = await toolbox.executeAction(session, action);
          session.observationHistory.add('Tool ${action.toolId} result: $result');
        } else if (outcome == PermissionOutcome.stopTask) {
          session.state = AgentSessionState.stopped;
          throw TaskStoppedException('User explicitly stopped the task during ${action.toolId}.');
        } else if (outcome == PermissionOutcome.denyAndReplan) {
          session.state = AgentSessionState.replanning;
          session.deniedTools.add({
            'toolId': action.toolId,
            'reason': 'user_denied'
          });
          session.observationHistory.add('Tool ${action.toolId} was denied by user. Replanning...');
          return false; // Break the current plan, force a replan
        }
      } on RecoverableToolException catch (e) {
        session.state = AgentSessionState.replanning;
        session.observationHistory.add('Tool ${action.toolId} failed (recoverable): ${e.message}. Replanning...');
        return false;
      } on FatalToolException catch (e) {
        session.state = AgentSessionState.failed;
        session.observationHistory.add('Tool ${action.toolId} failed fatally: ${e.message}.');
        return false;
      } catch (e) {
        session.state = AgentSessionState.failed;
        session.observationHistory.add('Tool ${action.toolId} failed with unexpected error: $e');
        return false; // Break current plan on other errors
      }

      session.executedActions.add(action);
      session.results[step.id] = result;

      permissionPolicy.onActionComplete(action.toolId);
    }
    return false; // Plan finished but goal not marked explicitly complete
  }

  /// Hook for human-in-the-loop authorization
  Future<PermissionOutcome> requestPermission(AgentAction action);
}
