import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../agent/models/agent_action.dart';
import '../../agent/models/agent_session.dart';
import '../../agent/models/permission_outcome.dart';
import '../../agent/models/tool_result.dart';
import '../../application/services/agent_orchestrator_service.dart';
import '../../core/noema_project.dart';

class PermissionRequest {
  final AgentAction action;
  final Completer<PermissionOutcome> completer;

  PermissionRequest(this.action, this.completer);
}

class UIObservation {
  final String description;
  final bool isError;
  final bool isPending;
  final String? resultText;
  final DateTime timestamp;

  UIObservation({
    required this.description,
    this.isError = false,
    this.isPending = false,
    this.resultText,
    required this.timestamp,
  });
}

class AgentState extends ChangeNotifier {
  final AgentOrchestratorService _orchestrator;
  
  PermissionRequest? _pendingPermission;
  
  AgentState(this._orchestrator) {
    _orchestrator.onStateChanged = _onStateChanged;
    _orchestrator.onPermissionRequested = _onPermissionRequested;
  }

  // Derived Properties
  bool get isRunning {
    final state = _orchestrator.currentSession?.state;
    return state == AgentSessionState.running || state == AgentSessionState.replanning;
  }

  bool get isWaitingForJobs => _orchestrator.currentSession?.state == AgentSessionState.waitingForJobs;
  
  String get currentStatus {
    switch (_orchestrator.currentSession?.state) {
      case AgentSessionState.initial: return "Idle";
      case AgentSessionState.running: return "Thinking...";
      case AgentSessionState.replanning: return "Replanning...";
      case AgentSessionState.waitingForPermission: return "Waiting for permission...";
      case AgentSessionState.waitingForJobs: return "Waiting for job completion...";
      case AgentSessionState.completed: return "Completed";
      case AgentSessionState.stopped: return "Stopped";
      case AgentSessionState.failed: return "Failed";
      case AgentSessionState.iterationLimitReached: return "Limit reached";
      case null: return "Inactive";
    }
  }

  List<UIObservation> get history {
    final session = _orchestrator.currentSession;
    if (session == null) return [];
    
    final List<UIObservation> result = [];
    
    // Map executed actions and observations
    for (var i = 0; i < session.executedActions.length; i++) {
      // Future: Map executed actions properly if needed
    }
    
    // For now, let's just map observations to UIObservations
    for (final obs in session.observations) {
      bool isError = obs.result.status != ToolResultStatus.success;
      String? resultText = obs.result.error ?? 
        (obs.result.artifacts != null && obs.result.artifacts!.isNotEmpty ? 'Generated ${obs.result.artifacts!.first.type}' : null) ??
        (obs.result.jobs != null && obs.result.jobs!.isNotEmpty ? 'Job pending...' : 'Success');

      final isPendingJob = obs.result.jobs != null && obs.result.jobs!.isNotEmpty;
      
      // If we later find a completion observation for this stepId, we could update this.
      // But the session appends a new observation for the completion.
      // We will just show them linearly.
      
      result.add(UIObservation(
        description: 'Used ${obs.toolId}',
        isError: isError,
        isPending: isPendingJob, // Linear logs
        resultText: resultText,
        timestamp: obs.timestamp,
      ));
    }
    
    return result.reversed.toList();
  }

  PermissionRequest? get pendingPermission => _pendingPermission;

  // Actions
  Future<void> startTask(NoemaProject project, String goal) async {
    _pendingPermission = null;
    notifyListeners();
    await _orchestrator.startTask(project, goal);
  }

  void stopTask() {
    _orchestrator.stopTask();
  }

  void resolvePermission(bool allow, {String? denyReason, bool stop = false}) {
    if (_pendingPermission == null) return;

    if (stop) {
      _pendingPermission!.completer.complete(PermissionOutcome.stopTask);
    } else if (allow) {
      _pendingPermission!.completer.complete(PermissionOutcome.allow);
    } else {
      _pendingPermission!.completer.complete(PermissionOutcome.denyAndReplan);
    }
    
    _pendingPermission = null;
    notifyListeners();
  }

  void _onStateChanged() {
    notifyListeners();
  }

  Future<PermissionOutcome> _onPermissionRequested(AgentAction action) {
    final completer = Completer<PermissionOutcome>();
    _pendingPermission = PermissionRequest(action, completer);
    notifyListeners();
    return completer.future;
  }
}
