import 'models/agent_plan.dart';
import 'models/agent_action.dart';
import 'models/agent_session.dart';
import 'models/permission_outcome.dart';
import 'models/tool_result.dart';
import 'models/agent_observation.dart';
import 'agent_toolbox.dart';
import 'permissions/permission_policy.dart';
import '../models/job.dart';

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
      session.observations.add(AgentObservation(
        stepId: 'iteration_${i + 1}',
        toolId: 'system',
        result: ToolResult(toolId: 'system', status: ToolResultStatus.success, data: {'message': 'Iteration ${i + 1} started.'}),
        timestamp: DateTime.now(),
      ));
      
      final plan = await formulatePlan(session);
      session.currentPlan = plan;
      
      if (plan.steps.isEmpty) {
        // Check if there are pending jobs we are waiting for
        final hasPendingJobs = session.observations.any((obs) {
          final jobs = obs.result.jobs;
          if (jobs == null || jobs.isEmpty) return false;
          
          // Find the last observation for this stepId
          final lastObsForStep = session.observations.lastWhere((o) => o.stepId == obs.stepId);
          
          // If the last observation for this step is a success but has no artifacts and no error, it's still pending
          // (Assuming job completion either provides an artifact or changes status to failure/recoverableFailure)
          // Also, if the tool inherently doesn't produce artifacts, we should probably check if this was injected by onJobEvent.
          // To be robust, let's assume a job is pending if the last observation doesn't have artifacts and is successful,
          // BUT wait, what if a job completes without artifacts?
          // Let's check if the last observation is the SAME as the initial one. If so, it's pending.
          if (lastObsForStep == obs) {
            // It's the only observation for this step so far. Is it a pending job?
            // A pending job observation has jobs but no artifacts.
            return obs.result.artifacts == null && obs.result.status == ToolResultStatus.success;
          }
          return false;
        });

        if (hasPendingJobs) {
          session.observations.add(AgentObservation(
            stepId: 'iteration_${i + 1}_waiting',
            toolId: 'system',
            result: ToolResult(toolId: 'system', status: ToolResultStatus.success, data: {'message': 'Waiting for pending jobs to complete.'}),
            timestamp: DateTime.now(),
          ));
          session.state = AgentSessionState.waitingForJobs;
          break; // Suspend the loop
        } else {
          session.observations.add(AgentObservation(
            stepId: 'iteration_${i + 1}_empty',
            toolId: 'system',
            result: ToolResult(toolId: 'system', status: ToolResultStatus.fatalFailure, error: 'Plan formulated with 0 steps. Assuming stuck.'),
            timestamp: DateTime.now(),
          ));
          session.state = AgentSessionState.failed;
          break;
        }
      }

      final completed = await executePlan(session, plan);
      if (completed) {
        session.state = AgentSessionState.completed;
        session.observations.add(AgentObservation(
          stepId: 'iteration_${i + 1}_completed',
          toolId: 'system',
          result: ToolResult(toolId: 'system', status: ToolResultStatus.success, data: {'message': 'Task marked as complete by Agent.'}),
          timestamp: DateTime.now(),
        ));
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
      ToolResult? result;

      try {
        result = await toolbox.executeAction(session, action);
        
        if (action.toolId == 'task_complete') {
          return true; // Goal achieved
        }
        
        session.observations.add(AgentObservation(
          stepId: step.id,
          toolId: action.toolId,
          result: result,
          timestamp: DateTime.now(),
        ));
      } on UnauthorizedException {
        session.state = AgentSessionState.waitingForPermission;
        final outcome = await requestPermission(action);
        
        if (outcome == PermissionOutcome.allow) {
          // Granted, try again immediately
          session.state = AgentSessionState.running;
          result = await toolbox.executeAction(session, action);
          session.observations.add(AgentObservation(
            stepId: step.id,
            toolId: action.toolId,
            result: result,
            timestamp: DateTime.now(),
          ));
        } else if (outcome == PermissionOutcome.stopTask) {
          session.state = AgentSessionState.stopped;
          throw TaskStoppedException('User explicitly stopped the task during ${action.toolId}.');
        } else if (outcome == PermissionOutcome.denyAndReplan) {
          session.state = AgentSessionState.replanning;
          session.deniedTools.add({
            'toolId': action.toolId,
            'reason': 'user_denied'
          });
          // Do not add a normal observation for denial. The deniedTools handles it.
          return false; // Break the current plan, force a replan
        }
      } on RecoverableToolException catch (e) {
        session.state = AgentSessionState.replanning;
        session.observations.add(AgentObservation(
          stepId: step.id,
          toolId: action.toolId,
          result: ToolResult(
            toolId: action.toolId,
            status: ToolResultStatus.recoverableFailure,
            error: e.message,
          ),
          timestamp: DateTime.now(),
        ));
        return false;
      } on FatalToolException catch (e) {
        session.state = AgentSessionState.failed;
        session.observations.add(AgentObservation(
          stepId: step.id,
          toolId: action.toolId,
          result: ToolResult(
            toolId: action.toolId,
            status: ToolResultStatus.fatalFailure,
            error: e.message,
          ),
          timestamp: DateTime.now(),
        ));
        return false;
      } catch (e) {
        session.state = AgentSessionState.failed;
        session.observations.add(AgentObservation(
          stepId: step.id,
          toolId: action.toolId,
          result: ToolResult(
            toolId: action.toolId,
            status: ToolResultStatus.fatalFailure,
            error: e.toString(),
          ),
          timestamp: DateTime.now(),
        ));
        return false; // Break current plan on other errors
      }

      session.executedActions.add(action);
      if (result != null) {
        session.results[step.id] = result;
      }

      permissionPolicy.onActionComplete(action.toolId);
    }
    return false; // Plan finished but goal not marked explicitly complete
  }

  /// Hook for human-in-the-loop authorization
  Future<PermissionOutcome> requestPermission(AgentAction action);

  /// Translates JobManager events into AgentObservations asynchronously.
  void onJobEvent(AgentSession session, Job job) {
    if (job.status != JobStatus.completed && job.status != JobStatus.failed && job.status != JobStatus.cancelled) {
      return; // Only care about terminal states
    }

    // Find the original observation that submitted this job
    // Search from newest to oldest
    AgentObservation? initialObs;
    for (final obs in session.observations.reversed) {
      if (obs.result.jobs != null && obs.result.jobs!.any((j) => j.jobId == job.id)) {
        initialObs = obs;
        break;
      }
    }

    if (initialObs == null) {
      // This job was not started by the agent in this session (or we lost context)
      return;
    }

    ToolResultStatus newStatus;
    List<ArtifactReference>? artifacts;
    String? error;

    if (job.status == JobStatus.completed) {
      newStatus = ToolResultStatus.success;
      if (job.result != null) {
        artifacts = [ArtifactReference(artifactId: job.result!, type: 'generated_artifact')];
      }
    } else if (job.status == JobStatus.cancelled) {
      newStatus = ToolResultStatus.recoverableFailure;
      error = 'Job cancelled by user or system.';
    } else {
      newStatus = ToolResultStatus.fatalFailure;
      error = job.error?.message ?? 'Job failed with unknown error.';
    }

    final newObs = AgentObservation(
      stepId: initialObs.stepId, // Preserve correlation
      toolId: initialObs.toolId,
      result: ToolResult(
        toolId: initialObs.toolId,
        status: newStatus,
        jobs: [JobReference(jobId: job.id, type: job.type)],
        artifacts: artifacts,
        error: error,
      ),
      timestamp: DateTime.now(),
    );

    session.observations.add(newObs);

    // If the agent was explicitly waiting for jobs, wake it up
    if (session.state == AgentSessionState.waitingForJobs) {
      run(session); // Resume the agent loop
    }
  }
}
