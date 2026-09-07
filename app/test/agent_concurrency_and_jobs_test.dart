import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent.dart';
import 'package:noema_studio/agent/models/agent_action.dart';
import 'package:noema_studio/agent/models/agent_step.dart';
import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';
import 'package:noema_studio/agent/models/tool_result.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/job.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';

class DummyToolbox implements AgentToolbox {
  @override
  Future<ToolResult> executeAction(
    AgentSession session,
    AgentAction action,
  ) async {
    if (action.toolId == 'test_job') {
      return ToolResult(
        toolId: 'test_job',
        status: ToolResultStatus.success,
        jobs: [JobReference(jobId: 'j1', type: 'test')],
      );
    } else if (action.toolId == 'test_multi_job') {
      return ToolResult(
        toolId: 'test_multi_job',
        status: ToolResultStatus.success,
        jobs: [
          JobReference(jobId: 'multi1', type: 'test'),
          JobReference(jobId: 'multi2', type: 'test'),
        ],
      );
    }
    return ToolResult(toolId: action.toolId, status: ToolResultStatus.success);
  }

  @override
  List<AgentToolSchema> getAvailableTools() => [];
}

class ConcurrencyTestAgent extends Agent {
  int formulateCount = 0;
  bool isWaitingForJob = false;
  final String targetToolId;

  ConcurrencyTestAgent({
    required super.toolbox,
    required super.permissionPolicy,
    this.targetToolId = 'test_job',
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
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

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) async {
    return PermissionOutcome.allow;
  }
}

void main() {
  group('Agent Concurrency and Jobs', () {
    test('Job without artifact completes and loop resumes', () async {
      final agent = ConcurrencyTestAgent(
        toolbox: DummyToolbox(),
        permissionPolicy: PermissionPolicy(),
      );
      final session = AgentSession(
        currentProject: NoemaProject(
          id: '1',
          idea: '',
          story: Story(title: '', scenes: []),
        ),
        currentGoal: 'test',
      );

      await agent.run(session);

      expect(session.state, AgentSessionState.waitingForJobs);
      expect(agent.formulateCount, 1);

      // Complete job with no artifacts
      final job = Job(
        id: 'j1',
        providerId: 'test_provider',
        type: 'test',
        status: JobStatus.completed,
      );

      agent.onJobEvent(session, job);

      // wait a bit for async run to finish
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        session.state,
        AgentSessionState.failed,
      ); // since formulatePlan returns 0 steps and no pending jobs
      expect(agent.formulateCount, 2);
    });

    test('Two concurrent run calls do not execute simultaneously', () async {
      final agent = ConcurrencyTestAgent(
        toolbox: DummyToolbox(),
        permissionPolicy: PermissionPolicy(),
      );
      final session = AgentSession(
        currentProject: NoemaProject(
          id: '1',
          idea: '',
          story: Story(title: '', scenes: []),
        ),
        currentGoal: 'test',
      );

      // Let's create a situation where run is called twice.
      final run1 = agent.run(session);
      final run2 = agent.run(session);

      await Future.wait([run1, run2]);

      // If it ran twice concurrently, formulateCount might be higher or it might crash.
      // With our protection, run2 returns immediately.
      // So run1 does 1 formulation (yields job, then checks hasPendingJobs and stops at waitingForJobs).
      expect(agent.formulateCount, 1);
    });

    test(
      'Agent spawns two jobs, waits for BOTH to complete before replanning',
      () async {
        final agent = ConcurrencyTestAgent(
          toolbox: DummyToolbox(),
          permissionPolicy: PermissionPolicy(),
          targetToolId: 'test_multi_job',
        );
        final session = AgentSession(
          currentProject: NoemaProject(
            id: '1',
            idea: '',
            story: Story(title: '', scenes: []),
          ),
          currentGoal: 'test',
        );

        await agent.run(session);

        expect(session.state, AgentSessionState.waitingForJobs);
        expect(agent.formulateCount, 1);

        // Job A completes
        final jobA = Job(
          id: 'multi1',
          providerId: 'test_provider',
          type: 'test',
          status: JobStatus.completed,
        );
        agent.onJobEvent(session, jobA);

        await Future.delayed(const Duration(milliseconds: 50));

        // Agent MUST remain waiting because multi2 is still pending
        expect(session.state, AgentSessionState.waitingForJobs);
        expect(agent.formulateCount, 1); // No new formulation

        // Job B completes
        final jobB = Job(
          id: 'multi2',
          providerId: 'test_provider',
          type: 'test',
          status: JobStatus.completed,
        );
        agent.onJobEvent(session, jobB);

        await Future.delayed(const Duration(milliseconds: 50));

        // Agent resumes, calls formulatePlan again which returns 0 steps -> fails
        expect(session.state, AgentSessionState.failed);
        expect(agent.formulateCount, 2);
      },
    );

    test('Agent spawns two jobs, waits for both even if one fails', () async {
      final agent = ConcurrencyTestAgent(
        toolbox: DummyToolbox(),
        permissionPolicy: PermissionPolicy(),
        targetToolId: 'test_multi_job',
      );
      final session = AgentSession(
        currentProject: NoemaProject(
          id: '1',
          idea: '',
          story: Story(title: '', scenes: []),
        ),
        currentGoal: 'test',
      );

      await agent.run(session);

      expect(session.state, AgentSessionState.waitingForJobs);
      expect(agent.formulateCount, 1);

      // Job A completes
      final jobA = Job(
        id: 'multi1',
        providerId: 'test_provider',
        type: 'test',
        status: JobStatus.completed,
      );
      agent.onJobEvent(session, jobA);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(session.state, AgentSessionState.waitingForJobs);

      // Job B fails
      final jobB = Job(
        id: 'multi2',
        providerId: 'test_provider',
        type: 'test',
        status: JobStatus.failed,
        error: JobError(code: 'ERR', message: 'test error'),
      );
      agent.onJobEvent(session, jobB);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(session.state, AgentSessionState.failed);
      expect(agent.formulateCount, 2);
    });
  });
}
