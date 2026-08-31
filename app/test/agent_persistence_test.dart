import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent.dart';
import 'package:noema_studio/agent/models/agent_action.dart';

import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_step.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';
import 'package:noema_studio/agent/models/tool_result.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';

class PersistenceTestToolbox implements AgentToolbox {
  final JobManager jobManager;

  PersistenceTestToolbox(this.jobManager);

  @override
  Future<ToolResult> executeAction(AgentSession session, AgentAction action) async {
    if (action.toolId == 'generate_image') {
      final job = Job(
        id: 'job_persistent_123',
        providerId: 'test_provider',
        type: 'image_job',
        status: JobStatus.running,
      );
      jobManager.add(job);
      return ToolResult(
        toolId: action.toolId,
        status: ToolResultStatus.success,
        jobs: [JobReference(jobId: job.id, type: job.type)],
      );
    }
    return ToolResult(toolId: action.toolId, status: ToolResultStatus.success);
  }

  @override
  List<AgentToolSchema> getAvailableTools() => [];
}

class PersistenceTestAgent extends Agent {
  final AgentPlan initialPlan;
  final AgentPlan emptyPlan;
  int formulateCount = 0;

  PersistenceTestAgent({
    required super.toolbox,
    required super.permissionPolicy,
    required this.initialPlan,
    required this.emptyPlan,
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    formulateCount++;
    if (formulateCount == 1) {
      return initialPlan;
    } else {
      return emptyPlan;
    }
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) async {
    return PermissionOutcome.allow;
  }
}

void main() {
  group('AgentSession Persistence and Recovery', () {
    test('Full round-trip persistence and application reconciliation', () async {
      // 1. Create runtime objects for initial state
      final originalJobManager = JobManager();
      final originalProject = NoemaProject(
        id: 'proj_persistence',
        idea: 'idea',
        story: Story(title: 'title', scenes: []),
      );
      
      final originalSession = AgentSession(
        currentProject: originalProject,
        currentGoal: 'draw image',
      );
      originalProject.agentSession = originalSession;

      final initialPlan = AgentPlan(
        goal: 'draw image',
        steps: [
          AgentStep(
            id: 'step_1',
            description: 'generate image',
            action: AgentAction(
              toolId: 'generate_image',
              riskLevel: ToolRiskLevel.moderate,
              arguments: {'prompt': 'persistent test'},
            ),
          )
        ],
      );

      final originalAgent = PersistenceTestAgent(
        toolbox: PersistenceTestToolbox(originalJobManager),
        permissionPolicy: PermissionPolicy(),
        initialPlan: initialPlan,
        emptyPlan: AgentPlan(goal: 'draw image', steps: []),
      );

      // Add dummy denied tools and execution history for serialization testing
      originalSession.deniedTools.add({'toolId': 'dangerous_tool', 'reason': 'user rejected'});

      // 2. Execute agent to generate job and enter waiting state
      await originalAgent.run(originalSession);

      // Verify Agent is in waiting state
      expect(originalSession.state, AgentSessionState.waitingForJobs);
      expect(originalJobManager.jobs.length, 1);
      final generatedJob = originalJobManager.jobs.first;

      // 3. Serialize to persist state
      originalProject.savedJobs.addAll(originalJobManager.jobs); // Simulating app closing behavior
      final serializedJson = jsonEncode(originalProject.toJson());

      // ----------------------------------------------------------------------
      // SIMULATE APPLICATION RESTART
      // ----------------------------------------------------------------------

      // 4. Restore domain state from JSON
      final parsedJson = jsonDecode(serializedJson) as Map<String, dynamic>;
      final restoredProject = NoemaProject.fromJson(parsedJson);

      // 5. Verify restored NoemaProject structure
      expect(restoredProject.id, 'proj_persistence');
      expect(restoredProject.agentSession, isNotNull);
      final restoredSession = restoredProject.agentSession!;
      
      // Verify AgentSession basic fields
      expect(restoredSession.currentGoal, 'draw image');
      expect(restoredSession.state, AgentSessionState.waitingForJobs);
      expect(restoredSession.deniedTools.length, 1);
      expect(restoredSession.deniedTools.first['toolId'], 'dangerous_tool');

      // Verify AgentSession correlation fields
      final restoredObservation = restoredSession.observations.lastWhere((o) => o.stepId == 'step_1');
      expect(restoredObservation.result.jobs!.first.jobId, generatedJob.id);

      // 6. Create fresh runtime objects
      final freshJobManager = JobManager();
      final freshAgent = PersistenceTestAgent(
        toolbox: PersistenceTestToolbox(freshJobManager),
        permissionPolicy: PermissionPolicy(),
        initialPlan: AgentPlan(goal: 'draw image', steps: []), // Agent is mid-execution, next plan is empty
        emptyPlan: AgentPlan(goal: 'draw image', steps: []),
      );

      // 7. Simulate JobManager restoration natively (which forces them to failed if they were running)
      // We will pretend the job COMPLETED externally while the app was closed.
      final externalCompletedJob = Job(
        id: generatedJob.id,
        providerId: generatedJob.providerId,
        type: generatedJob.type,
        status: JobStatus.completed,
        result: 'artifact_persisted_999',
      );
      freshJobManager.restoreJobs([externalCompletedJob]);

      // 8. Application Reconciliation
      // Orchestrator feeds restored jobs to the restored agent session
      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      // Wait a moment for async onJobEvent to process
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (restoredSession.state != AgentSessionState.waitingForJobs) break;
      }

      // 9. Verify Agent successfully resumed and evaluated the new context
      expect(restoredSession.state, AgentSessionState.failed); // Wakes up, formulates empty plan -> fails
      
      // Verify proper observation was injected using the restored step ID correlation
      final completionObs = restoredSession.observations.lastWhere((o) => o.stepId == 'step_1');
      expect(completionObs.result.status, ToolResultStatus.success);
      expect(completionObs.result.artifacts!.first.artifactId, 'artifact_persisted_999');
    });
  });
}
