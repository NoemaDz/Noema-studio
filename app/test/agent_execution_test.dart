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

class MockAction extends AgentAction {
  MockAction(String toolId, ToolRiskLevel riskLevel)
    : super(toolId: toolId, riskLevel: riskLevel);
}

class MockToolbox implements AgentToolbox {
  @override
  Future executeAction(AgentAction action) async {
    return {'status': 'ok'};
  }
}

class TestAgent extends Agent {
  bool willApprove = false;
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
  Future<bool> requestPermission(AgentAction action) async {
    approvalRequests++;
    if (willApprove) {
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
      toolbox = MockToolbox();
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

    test('fails if permission denied', () async {
      agent.willApprove = false;
      final plan = await agent.formulatePlan(session);

      await expectLater(
        agent.executePlan(session, plan),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Permission denied'),
          ),
        ),
      );
      expect(agent.approvalRequests, 1);
      expect(
        session.executedActions.length,
        1,
      ); // Only the 'safe' read action executed
    });

    test('succeeds if permission granted', () async {
      agent.willApprove = true;
      final plan = await agent.formulatePlan(session);

      await agent.executePlan(session, plan);

      expect(agent.approvalRequests, 1);
      expect(session.executedActions.length, 2);
    });
  });
}
