import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/agent/agent.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';
import 'package:noema_studio/agent/models/agent_action.dart';
import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_step.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/permissions/permission_scope.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/agent/permissions/agent_permission.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';

class MockAction extends AgentAction {
  MockAction(String toolId, ToolRiskLevel riskLevel)
    : super(toolId: toolId, riskLevel: riskLevel);
}

class MockToolbox implements AgentToolbox {
  final PermissionPolicy policy;

  MockToolbox(this.policy);

  @override
  Future executeAction(AgentSession session, AgentAction action) async {
    if (!policy.isAuthorized(action.toolId, action.riskLevel)) {
      throw UnauthorizedException(action.toolId);
    }
    if (action.toolId == 'recoverable') {
      throw RecoverableToolException('API timeout');
    }
    if (action.toolId == 'fatal') {
      throw FatalToolException('Disk full');
    }
    return {'status': 'ok'};
  }

  @override
  List<AgentToolSchema> getAvailableTools() {
    return [];
  }
}

class TestAgent extends Agent {
  PermissionOutcome willApprove = PermissionOutcome.allow;
  int approvalRequests = 0;

  TestAgent({required super.toolbox, required super.permissionPolicy});

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    return AgentPlan(
      goal: session.currentGoal,
      steps: [
        AgentStep(
          id: '1',
          description: 'Read',
          action: MockAction('read', ToolRiskLevel.safe),
        ),
        AgentStep(
          id: '2',
          description: 'Write',
          action: MockAction('write', ToolRiskLevel.high),
        ),
      ],
    );
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) async {
    approvalRequests++;
    if (willApprove == PermissionOutcome.allow) {
      permissionPolicy.grant(
        AgentPermission(
          toolId: action.toolId,
          scope: PermissionScope.once,
          grantedAt: DateTime.now(),
        ),
      );
    }
    return willApprove;
  }
}

void main() {
  group('Agent Execution Flow', () {
    late PermissionPolicy policy;
    late MockToolbox toolbox;
    late TestAgent agent;
    late AgentSession session;

    setUp(() {
      policy = PermissionPolicy();
      toolbox = MockToolbox(policy);
      agent = TestAgent(toolbox: toolbox, permissionPolicy: policy);

      final mockStory = Story(title: 'test', scenes: []);
      session = AgentSession(
        currentProject: NoemaProject(
          id: 'test',
          idea: 'test idea',
          story: mockStory,
        ),
        currentGoal: 'test goal',
      );
    });

    test(
      'deny -> stopTask: fails execution and throws TaskStoppedException',
      () async {
        agent.willApprove = PermissionOutcome.stopTask;
        final plan = await agent.formulatePlan(session);

        await expectLater(
          agent.executePlan(session, plan),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User explicitly stopped the task'),
            ),
          ),
        );
        expect(agent.approvalRequests, 1);
        expect(
          session.executedActions.length,
          1,
        ); // Only the 'safe' read action executed
        expect(session.state, AgentSessionState.stopped);
      },
    );

    test(
      'grant -> retry: catches UnauthorizedException, prompts user, and retries successfully',
      () async {
        agent.willApprove = PermissionOutcome.allow;
        final plan = await agent.formulatePlan(session);

        await agent.executePlan(session, plan);

        expect(agent.approvalRequests, 1);
        // Both actions executed, first safe tool passed natively, second threw, caught, approved, retried.
        expect(session.executedActions.length, 2);
      },
    );
    test('denyAndReplan: aborts plan and adds to deniedTools', () async {
      agent.willApprove = PermissionOutcome.denyAndReplan;
      final plan = await agent.formulatePlan(session);

      await agent.executePlan(session, plan);

      expect(agent.approvalRequests, 1);
      expect(session.executedActions.length, 1);
      expect(session.deniedTools.length, 1);
      expect(session.deniedTools.first['toolId'], 'write');
      expect(session.state, AgentSessionState.replanning);
    });

    test('recoverable failure -> replan', () async {
      agent.willApprove = PermissionOutcome.allow;
      final plan = AgentPlan(
        goal: session.currentGoal,
        steps: [
          AgentStep(
            id: '1',
            description: 'Recoverable',
            action: MockAction('recoverable', ToolRiskLevel.safe),
          ),
        ],
      );

      final completed = await agent.executePlan(session, plan);

      expect(completed, false);
      expect(session.state, AgentSessionState.replanning);
      expect(session.observationHistory.last, contains('failed (recoverable): API timeout'));
    });

    test('fatal failure -> failed', () async {
      agent.willApprove = PermissionOutcome.allow;
      final plan = AgentPlan(
        goal: session.currentGoal,
        steps: [
          AgentStep(
            id: '1',
            description: 'Fatal',
            action: MockAction('fatal', ToolRiskLevel.safe),
          ),
        ],
      );

      final completed = await agent.executePlan(session, plan);

      expect(completed, false);
      expect(session.state, AgentSessionState.failed);
      expect(session.observationHistory.last, contains('failed fatally: Disk full'));
    });
  });
}
