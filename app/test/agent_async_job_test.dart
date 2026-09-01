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

void main() {
  group('Agent Async Job Pipeline', () {
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

      // Listen to job manager events and forward them to the agent
      jobManager.onJobUpdated.listen((job) {
        agent.onJobEvent(session, job);
      });
    });

    test('Agent suspends when waiting for job and resumes on completion', () async {
      // 1. Run agent. It should execute generate_image, then formulate again, get empty plan, and suspend.
      await agent.run(session);

      // Verify suspended state
      expect(session.state, AgentSessionState.waitingForJobs);
      expect(agent.formulateCount, 1);

      // Check observation of submitted job
      final submissionObs = session.observations.firstWhere(
        (o) => o.stepId == 'step_1',
      );
      expect(submissionObs.result.jobs!.first.jobId, 'job_123');

      // 2. Simulate Job completion from JobManager
      jobManager.complete('job_123', 'artifact_456');

      // We need to yield to the event loop and wait for the async `run` to complete
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (session.state != AgentSessionState.waitingForJobs) break;
      }

      // Verify the agent resumed and formulated again
      // Wait, agent.run(session) was called inside onJobEvent which is async.
      // So agent.run finishes, we check states.
      expect(agent.formulateCount, 2); // Woke up and formulated again

      // Since formulateCount == 2, it returned emptyPlan again, but this time there are NO pending jobs, so it should fail.
      expect(session.state, AgentSessionState.failed);

      // Verify the injected observation
      final completionObs = session.observations.lastWhere(
        (o) => o.stepId == 'step_1',
      );
      expect(completionObs.result.status, ToolResultStatus.success);
      expect(completionObs.result.artifacts!.first.artifactId, 'artifact_456');
    });

    test('Agent resumes on job failure', () async {
      await agent.run(session);
      expect(session.state, AgentSessionState.waitingForJobs);

      // Simulate Job failure
      jobManager.fail(
        'job_123',
        JobError(code: 'err1', message: 'Failed to generate'),
      );

      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
        if (session.state != AgentSessionState.waitingForJobs) break;
      }

      expect(agent.formulateCount, 2);
      expect(
        session.state,
        AgentSessionState.failed,
      ); // Fails because of empty plan after resume

      final completionObs = session.observations.lastWhere(
        (o) => o.stepId == 'step_1',
      );
      expect(completionObs.result.status, ToolResultStatus.fatalFailure);
      expect(completionObs.result.error, 'Failed to generate');
    });
  });
}
