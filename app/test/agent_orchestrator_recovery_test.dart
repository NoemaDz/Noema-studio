import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/models/agent_action.dart';
import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_step.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';
import 'package:noema_studio/agent/models/tool_result.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';
import 'package:noema_studio/application/services/agent_orchestrator_service.dart';
import 'package:noema_studio/core/job_events.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/models/story.dart' as import_story;
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/llm_client.dart';
import 'package:noema_studio/models/job.dart';

class MockLlmClient implements LlmClient {
  String responseText = '[]';
  @override
  Future<String> generateText(String prompt) async {
    return responseText;
  }
}

class MockToolbox implements AgentToolbox {
  final JobManager jobManager;
  int spawnCount = 0;

  MockToolbox(this.jobManager);

  @override
  Future<ToolResult> executeAction(
    AgentSession session,
    AgentAction action,
  ) async {
    if (action.toolId == 'test_job') {
      spawnCount++;
      final job = Job(
        id: 'job_$spawnCount',
        providerId: 'test_provider',
        type: 'test',
        status: JobStatus.running,
      );
      jobManager.add(job);
      return ToolResult(
        toolId: action.toolId,
        status: ToolResultStatus.success,
        jobs: [JobReference(jobId: job.id, type: job.type)],
      );
    } else if (action.toolId == 'test_multi_job') {
      final job1 = Job(
        id: 'jA',
        providerId: 'test',
        type: 'test',
        status: JobStatus.running,
      );
      final job2 = Job(
        id: 'jB',
        providerId: 'test',
        type: 'test',
        status: JobStatus.running,
      );
      jobManager.add(job1);
      jobManager.add(job2);
      return ToolResult(
        toolId: action.toolId,
        status: ToolResultStatus.success,
        jobs: [
          JobReference(jobId: job1.id, type: job1.type),
          JobReference(jobId: job2.id, type: job2.type),
        ],
      );
    }
    return ToolResult(toolId: action.toolId, status: ToolResultStatus.success);
  }

  @override
  List<AgentToolSchema> getAvailableTools() => [];
}

class TestPlanner extends AgentPlanner {
  final String targetToolId;
  int formulateCount = 0;
  bool isWaitingForJob = false;

  TestPlanner({
    required super.llmClient,
    required super.toolbox,
    this.targetToolId = 'test_job',
    this.isWaitingForJob = false,
  });

  @override
  Future<AgentPlan> formulatePlan(
    AgentSession session, {
    int maxRetries = 3,
  }) async {
    formulateCount++;
    if (!isWaitingForJob) {
      isWaitingForJob = true;
      return AgentPlan(
        goal: 'test',
        steps: [
          AgentStep(
            id: 'step1',
            description: 'Test',
            action: AgentAction(
              toolId: targetToolId,
              riskLevel: ToolRiskLevel.safe,
              arguments: {},
            ),
          ),
        ],
      );
    }
    return AgentPlan(goal: 'test', steps: []);
  }
}

AgentSession cloneSession(AgentSession original) {
  final cloned = AgentSession(
    currentProject: original.currentProject,
    currentGoal: original.currentGoal,
    currentPlan: original.currentPlan,
  );
  cloned.state = original.state;
  cloned.observations.addAll(original.observations);
  cloned.executedActions.addAll(original.executedActions);
  cloned.results.addAll(original.results);
  cloned.deniedTools.addAll(original.deniedTools);
  return cloned;
}

void main() {
  group('Agent Orchestrator Recovery Tests', () {
    test('Real restart recovery ordering', () async {
      final oldJobEvents = JobEvents();
      final oldJobManager = JobManager();
      final oldToolbox = MockToolbox(oldJobManager);
      final oldPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: oldToolbox,
      );

      final oldOrchestrator = AgentOrchestratorService(
        toolbox: oldToolbox,
        jobEvents: oldJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: oldPlanner,
        jobManager: oldJobManager,
      );

      final project = NoemaProject(
        id: 'p1',
        idea: 'test',
        story: import_story.Story(title: 't', scenes: []),
      );

      await oldOrchestrator.startTask(project, "test");
      expect(
        oldOrchestrator.currentSession!.state,
        AgentSessionState.waitingForJobs,
      );
      expect(oldPlanner.formulateCount, 1);

      // Simulate App Restart
      final persistedSession = cloneSession(oldOrchestrator.currentSession!);

      final freshJobEvents = JobEvents();
      final freshJobManager = JobManager();
      // restoreJobs converts running jobs to failed BEFORE event listeners attach
      freshJobManager.restoreJobs([
        Job(
          id: 'job_1',
          providerId: 'test_provider',
          type: 'test',
          status: JobStatus.running,
        ),
      ]);
      expect(freshJobManager.find('job_1')!.status, JobStatus.failed);

      final freshPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: MockToolbox(freshJobManager),
        isWaitingForJob: true,
      );
      final freshOrchestrator = AgentOrchestratorService(
        toolbox: MockToolbox(freshJobManager),
        jobEvents: freshJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: freshPlanner,
        jobManager: freshJobManager,
      );

      // Now resume session which should reconcile
      await freshOrchestrator.resumeSession(persistedSession);

      // The session should have resumed exactly once, observed the failure, replanned, and failed.
      expect(persistedSession.state, AgentSessionState.failed);
      expect(freshPlanner.formulateCount, 1); // Replanned once
    });

    test('Multiple Recovered Jobs do not cause recursive resume', () async {
      final oldJobEvents = JobEvents();
      final oldJobManager = JobManager();
      final oldToolbox = MockToolbox(oldJobManager);
      final oldPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: oldToolbox,
        targetToolId: 'test_multi_job',
      );

      final oldOrchestrator = AgentOrchestratorService(
        toolbox: oldToolbox,
        jobEvents: oldJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: oldPlanner,
        jobManager: oldJobManager,
      );

      final project = NoemaProject(
        id: 'p2',
        idea: 'test',
        story: import_story.Story(title: 't', scenes: []),
      );

      await oldOrchestrator.startTask(project, "test");
      expect(
        oldOrchestrator.currentSession!.state,
        AgentSessionState.waitingForJobs,
      );

      // Simulate App Restart
      final persistedSession = cloneSession(oldOrchestrator.currentSession!);

      final freshJobEvents = JobEvents();
      final freshJobManager = JobManager();
      freshJobManager.restoreJobs([
        Job(
          id: 'jA',
          providerId: 'test',
          type: 'test',
          status: JobStatus.running,
        ),
        Job(
          id: 'jB',
          providerId: 'test',
          type: 'test',
          status: JobStatus.running,
        ),
      ]);

      final freshPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: MockToolbox(freshJobManager),
        isWaitingForJob: true,
      );
      final freshOrchestrator = AgentOrchestratorService(
        toolbox: MockToolbox(freshJobManager),
        jobEvents: freshJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: freshPlanner,
        jobManager: freshJobManager,
      );

      await freshOrchestrator.resumeSession(persistedSession);

      expect(persistedSession.state, AgentSessionState.failed);
      expect(freshPlanner.formulateCount, 1); // Exactly one resume

      // Ensure only one wait observation was created in the fresh session
      final waitObs = persistedSession.observations
          .where((o) => o.stepId.endsWith('_waiting'))
          .length;
      expect(waitObs, 1); // Only the one from the original session
    });

    test('Idempotency Regression Test', () async {
      final oldJobEvents = JobEvents();
      final oldJobManager = JobManager();
      final oldToolbox = MockToolbox(oldJobManager);
      final oldPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: oldToolbox,
      );

      final oldOrchestrator = AgentOrchestratorService(
        toolbox: oldToolbox,
        jobEvents: oldJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: oldPlanner,
        jobManager: oldJobManager,
      );

      final project = NoemaProject(
        id: 'p3',
        idea: 'test',
        story: import_story.Story(title: 't', scenes: []),
      );

      await oldOrchestrator.startTask(project, "test");

      final persistedSession = cloneSession(oldOrchestrator.currentSession!);

      final freshJobEvents = JobEvents();
      final freshJobManager = JobManager();
      freshJobManager.restoreJobs([
        Job(
          id: 'job_1',
          providerId: 'test_provider',
          type: 'test',
          status: JobStatus.running,
        ),
      ]);

      final freshPlanner = TestPlanner(
        llmClient: MockLlmClient(),
        toolbox: MockToolbox(freshJobManager),
        isWaitingForJob: true,
      );
      final freshOrchestrator = AgentOrchestratorService(
        toolbox: MockToolbox(freshJobManager),
        jobEvents: freshJobEvents,
        permissionPolicy: PermissionPolicy(),
        planner: freshPlanner,
        jobManager: freshJobManager,
      );

      await freshOrchestrator.resumeSession(persistedSession);
      final obsCount = persistedSession.observations.length;
      expect(persistedSession.state, AgentSessionState.failed);
      expect(freshPlanner.formulateCount, 1);

      // Call resumeSession again
      await freshOrchestrator.resumeSession(persistedSession);

      // State should not change, no duplicate planning, no duplicate observations
      expect(persistedSession.state, AgentSessionState.failed);
      expect(freshPlanner.formulateCount, 1);
      expect(persistedSession.observations.length, obsCount);
    });
  });
}
