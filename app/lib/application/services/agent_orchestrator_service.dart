import 'dart:async';
import '../../agent/agent.dart';
import '../../agent/models/agent_action.dart';
import '../../agent/models/agent_plan.dart';
import '../../agent/models/agent_session.dart';
import '../../agent/models/permission_outcome.dart';
import '../../agent/permissions/permission_policy.dart';
import '../../agent/agent_toolbox.dart';
import '../../core/job_events.dart';
import '../../core/noema_project.dart';

class OrchestratedAgent extends Agent {
  final Future<PermissionOutcome> Function(AgentAction action) onRequest;

  OrchestratedAgent({
    required super.toolbox,
    required super.permissionPolicy,
    required this.onRequest,
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    // Basic fallback since this orchestrator doesn't yet have LLM planner injected
    return AgentPlan(goal: session.currentGoal, steps: []);
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) {
    return onRequest(action);
  }
}

class AgentOrchestratorService {
  final AgentToolbox toolbox;
  final JobEvents jobEvents;
  final PermissionPolicy permissionPolicy;
  late final OrchestratedAgent _agent;
  
  AgentSession? _currentSession;
  StreamSubscription? _jobSubscription;

  // Callbacks for Presentation State
  void Function()? onStateChanged;
  Future<PermissionOutcome> Function(AgentAction action)? onPermissionRequested;

  AgentSession? get currentSession => _currentSession;

  AgentOrchestratorService({
    required this.toolbox,
    required this.jobEvents,
    required this.permissionPolicy,
  }) {
    _agent = OrchestratedAgent(
      toolbox: toolbox,
      permissionPolicy: permissionPolicy,
      onRequest: _handlePermissionRequest,
    );
  }

  void attachJobEvents() {
    _jobSubscription?.cancel();
    _jobSubscription = jobEvents.stream.listen((job) {
      if (_currentSession != null) {
        final session = _currentSession!;
        _agent.onJobEvent(session, job);
        onStateChanged?.call();
      }
    });
  }

  void detachJobEvents() {
    _jobSubscription?.cancel();
    _jobSubscription = null;
  }

  Future<PermissionOutcome> _handlePermissionRequest(AgentAction action) async {
    if (onPermissionRequested != null) {
      return await onPermissionRequested!(action);
    }
    return PermissionOutcome.allow; // Fallback if no UI attached
  }

  /// Start a brand new agent session
  Future<void> startTask(NoemaProject project, String goal) async {
    _currentSession = AgentSession(
      currentProject: project,
      currentGoal: goal,
    );
    project.agentSession = _currentSession;
    
    attachJobEvents();
    onStateChanged?.call();

    await _runCurrentSession();
  }

  /// Resume a restored session (e.g. after app restart)
  Future<void> resumeSession(AgentSession session) async {
    _currentSession = session;
    attachJobEvents();
    onStateChanged?.call();

    if (session.state == AgentSessionState.running || 
        session.state == AgentSessionState.replanning) {
      await _runCurrentSession();
    }
  }

  /// Explicitly stop the current task
  void stopTask() {
    if (_currentSession != null && _currentSession!.state != AgentSessionState.completed && _currentSession!.state != AgentSessionState.failed) {
      _currentSession!.state = AgentSessionState.stopped;
      onStateChanged?.call();
    }
  }

  Future<void> _runCurrentSession() async {
    if (_currentSession == null) return;
    
    // The Agent.run is fully asynchronous and event-driven.
    // It will yield control when waitingForJobs or requesting permissions.
    await _agent.run(_currentSession!);
    
    onStateChanged?.call();
  }
}
