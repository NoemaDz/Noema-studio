import 'dart:async';
import '../../agent/agent.dart';
import '../../agent/models/agent_action.dart';
import '../../agent/models/agent_plan.dart';
import '../../agent/models/agent_session.dart';
import '../../agent/models/permission_outcome.dart';
import '../../agent/permissions/permission_policy.dart';
import '../../agent/agent_toolbox.dart';
import '../../agent/agent_planner.dart';
import '../../core/job_events.dart';
import '../../core/job_manager.dart';
import '../../core/noema_project.dart';
import '../../models/job.dart';

class OrchestratedAgent extends Agent {
  final Future<PermissionOutcome> Function(AgentAction action) onRequest;

  final AgentPlanner planner;

  OrchestratedAgent({
    required super.toolbox,
    required super.permissionPolicy,
    required this.onRequest,
    required this.planner,
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    return await planner.formulatePlan(session);
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
  final AgentPlanner planner;
  final JobManager jobManager;
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
    required this.planner,
    required this.jobManager,
  }) {
    _agent = OrchestratedAgent(
      toolbox: toolbox,
      permissionPolicy: permissionPolicy,
      onRequest: _handlePermissionRequest,
      planner: planner,
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
    _currentSession = AgentSession(currentProject: project, currentGoal: goal);
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

    if (session.state == AgentSessionState.waitingForJobs) {
      _reconcileWaitingJobs(session);
    }

    if (session.state == AgentSessionState.running ||
        session.state == AgentSessionState.replanning) {
      await _runCurrentSession();
    }
  }

  void _reconcileWaitingJobs(AgentSession session) {
    // 1. Identify jobs the session is waiting for
    final Set<String> spawnedJobs = {};
    final Set<String> terminalJobs = {};

    for (final obs in session.observations) {
      final jobs = obs.result.jobs;
      if (jobs == null || jobs.isEmpty) continue;

      final isTerminal = obs.result.data?['is_terminal_event'] == true;
      for (final jobRef in jobs) {
        if (isTerminal) {
          terminalJobs.add(jobRef.jobId);
        } else {
          spawnedJobs.add(jobRef.jobId);
        }
      }
    }

    final pendingJobIds = spawnedJobs.difference(terminalJobs).toList();
    if (pendingJobIds.isEmpty) return;

    // Temporarily suppress onJobEvent from waking up the agent
    final originalState = session.state;
    session.state = AgentSessionState.running;

    // 2. Query their state through JobManager and inject missing events if terminal
    bool allResolved = true;
    for (final jobId in pendingJobIds) {
      final job = jobManager.find(jobId);
      if (job != null) {
        if (job.status == JobStatus.completed ||
            job.status == JobStatus.failed ||
            job.status == JobStatus.cancelled) {
          _agent.onJobEvent(session, job);
        } else {
          allResolved = false;
        }
      } else {
        // If the job is entirely missing (e.g., lost during save/crash)
        // Synthesize a failed job to prevent indefinite hang
        final synthesizedJob = Job(
          id: jobId,
          providerId: 'unknown',
          type: 'unknown',
          status: JobStatus.failed,
          error: JobError(
            code: 'JOB_LOST',
            message: 'Job was lost during session recovery.',
          ),
        );
        _agent.onJobEvent(session, synthesizedJob);
      }
    }

    if (!allResolved) {
      // Revert state so it keeps waiting without triggering a new run loop
      session.state = originalState;
    }
    // If allResolved is true, session.state remains running, which causes _runCurrentSession() to be called in resumeSession()
  }

  /// Explicitly stop the current task
  void stopTask() {
    if (_currentSession != null &&
        _currentSession!.state != AgentSessionState.completed &&
        _currentSession!.state != AgentSessionState.failed) {
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
