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
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';

class MockAsyncToolbox implements AgentToolbox {
  final JobManager jobManager;

  MockAsyncToolbox(this.jobManager);

  @override
  Future<ToolResult> executeAction(
    AgentSession session,
    AgentAction action,
  ) async {
    if (action.toolId == 'generate_image') {
      final job = Job(
        id: 'job_123',
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

class TestAsyncAgent extends Agent {
  final AgentPlan initialPlan;
  final AgentPlan emptyPlan;
  int formulateCount = 0;

  TestAsyncAgent({
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

// Helper to manually clone session to simulate persistence
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
  group('Agent Restart/Reconciliation Pipeline', () {
    late AgentSession session;
    late PermissionPolicy policy;
    late JobManager jobManager;
    late MockAsyncToolbox toolbox;
    late TestAsyncAgent agent;

    setUp(() {
      policy = PermissionPolicy();
      jobManager = JobManager();
      toolbox = MockAsyncToolbox(jobManager);
      session = AgentSession(
        currentProject: NoemaProject(
          id: 'proj_test',
          idea: 'idea',
          story: Story(title: 'title', scenes: []),
        ),
        currentGoal: 'draw image',
      );

      final initialPlan = AgentPlan(
        goal: 'draw image',
        steps: [
          AgentStep(
            id: 'step_1',
            description: 'generate image',
            action: AgentAction(
              toolId: 'generate_image',
              riskLevel: ToolRiskLevel.moderate,
              arguments: {'prompt': 'test'},
            ),
          ),
        ],
      );

      agent = TestAsyncAgent(
        toolbox: toolbox,
        permissionPolicy: policy,
        initialPlan: initialPlan,
        emptyPlan: AgentPlan(goal: 'draw image', steps: []),
      );

      jobManager.onJobUpdated.listen((job) {
        agent.onJobEvent(session, job);
      });
    });

    test('Completed Job during restart', () async {
      // 1. Agent starts task
      await agent.run(session);

      // 4. Agent enters waiting-for-job state
      expect(session.state, AgentSessionState.waitingForJobs);

      // 5. Persist AgentSession (simulated)
      final persistedSession = cloneSession(session);

      // 6. Simulate application shutdown
      // 7. Create fresh JobManager and Agent
      final freshJobManager = JobManager();
      final freshToolbox = MockAsyncToolbox(freshJobManager);
      final freshAgent = TestAsyncAgent(
        toolbox: freshToolbox,
        permissionPolicy: policy,
        initialPlan: AgentPlan(
          goal: 'draw image',
          steps: [],
        ), // Agent is restored mid-execution, next formulate is empty
        emptyPlan: AgentPlan(goal: 'draw image', steps: []),
      );

      // 8. Restore persisted Jobs
      // Assume Job was completed while app was offline
      final restoredJob = Job(
        id: 'job_123',
        providerId: 'test_provider',
        type: 'image_job',
        status: JobStatus.completed,
        result: 'artifact_456', // Completed artifact
      );
      freshJobManager.restoreJobs([restoredJob]);

      // 9. Restore persisted AgentSession
      final restoredSession = cloneSession(persistedSession);

      // 10. Run Application reconciliation
      // 11. Forward restored Job
      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      // We need to yield to the event loop so the stream listener can run
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (restoredSession.state != AgentSessionState.waitingForJobs) break;
      }

      // 12. Verify Agent does NOT remain stuck
      expect(
        restoredSession.state,
        AgentSessionState.failed,
      ); // Fails because it wakes up and formulates empty plan

      // 13. Verify correct observation is produced
      final completionObs = restoredSession.observations.lastWhere(
        (o) => o.stepId == 'step_1',
      );
      expect(completionObs.result.status, ToolResultStatus.success);
      expect(completionObs.result.artifacts!.first.artifactId, 'artifact_456');
    });

    test('Failed Job during restart (e.g. app crash)', () async {
      await agent.run(session);
      expect(session.state, AgentSessionState.waitingForJobs);

      final persistedSession = cloneSession(session);

      final freshJobManager = JobManager();
      final freshAgent = TestAsyncAgent(
        toolbox: MockAsyncToolbox(freshJobManager),
        permissionPolicy: policy,
        initialPlan: AgentPlan(goal: '', steps: []),
        emptyPlan: AgentPlan(goal: '', steps: []),
      );

      // Restore as running (which JobManager will force to failed due to restart)
      final restoredJob = Job(
        id: 'job_123',
        providerId: 'test_provider',
        type: 'image_job',
        status: JobStatus.running,
      );
      freshJobManager.restoreJobs([
        restoredJob,
      ]); // JobManager internally changes status to failed

      final restoredSession = cloneSession(persistedSession);

      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (restoredSession.state != AgentSessionState.waitingForJobs) break;
      }

      expect(restoredSession.state, AgentSessionState.failed);

      final completionObs = restoredSession.observations.lastWhere(
        (o) => o.stepId == 'step_1',
      );
      expect(completionObs.result.status, ToolResultStatus.fatalFailure);
      expect(
        completionObs.result.error,
        'Job interrupted due to application restart',
      );
    });

    test('Still-running Job', () async {
      await agent.run(session);
      expect(session.state, AgentSessionState.waitingForJobs);

      final persistedSession = cloneSession(session);

      final freshJobManager = JobManager();
      final freshAgent = TestAsyncAgent(
        toolbox: MockAsyncToolbox(freshJobManager),
        permissionPolicy: policy,
        initialPlan: AgentPlan(goal: '', steps: []),
        emptyPlan: AgentPlan(goal: '', steps: []),
      );

      // Suppose we have a way to resume external provider jobs and they are still running
      final restoredJob = Job(
        id: 'job_123',
        providerId: 'test_provider',
        type: 'image_job',
        status: JobStatus.running, // Pretend the provider kept it running
      );
      // Directly add instead of restoreJobs to bypass the force-failed logic for this specific test
      freshJobManager.add(restoredJob);

      final restoredSession = cloneSession(persistedSession);

      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Expected: Agent remains waiting
      expect(restoredSession.state, AgentSessionState.waitingForJobs);
    });

    test('Unrelated Job', () async {
      await agent.run(session);
      expect(session.state, AgentSessionState.waitingForJobs);
      final persistedSession = cloneSession(session);

      final freshJobManager = JobManager();
      final freshAgent = TestAsyncAgent(
        toolbox: MockAsyncToolbox(freshJobManager),
        permissionPolicy: policy,
        initialPlan: AgentPlan(goal: '', steps: []),
        emptyPlan: AgentPlan(goal: '', steps: []),
      );

      final unrelatedJob = Job(
        id: 'job_999', // Different ID
        providerId: 'test_provider',
        type: 'image_job',
        status: JobStatus.completed,
      );
      freshJobManager.restoreJobs([unrelatedJob]);

      final restoredSession = cloneSession(persistedSession);

      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Expected: AgentSession ignores it and remains waiting
      expect(restoredSession.state, AgentSessionState.waitingForJobs);
    });

    test('Missing Job', () async {
      await agent.run(session);
      expect(session.state, AgentSessionState.waitingForJobs);
      final persistedSession = cloneSession(session);

      final freshJobManager = JobManager();
      final freshAgent = TestAsyncAgent(
        toolbox: MockAsyncToolbox(freshJobManager),
        permissionPolicy: policy,
        initialPlan: AgentPlan(goal: '', steps: []),
        emptyPlan: AgentPlan(goal: '', steps: []),
      );

      // No jobs restored!
      freshJobManager.restoreJobs([]);

      final restoredSession = cloneSession(persistedSession);

      for (final job in freshJobManager.jobs) {
        freshAgent.onJobEvent(restoredSession, job);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      // Expected: Agent does not silently assume success, it remains waiting
      expect(restoredSession.state, AgentSessionState.waitingForJobs);
    });
  });
}
