import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent.dart';
import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_step.dart';
import 'package:noema_studio/agent/models/agent_action.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'agent_planner_test.dart' show TestToolbox;
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';

class MockAgent extends Agent {
  int formulationCalls = 0;
  List<AgentPlan> plansToReturn = [];

  MockAgent({required super.toolbox, required super.permissionPolicy});

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    final plan = plansToReturn[formulationCalls];
    formulationCalls++;
    return plan;
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) async {
    return PermissionOutcome.allow;
  }
}

void main() {
  group('Agent Execution Loop', () {
    late AgentSession session;
    late PermissionPolicy policy;
    late TestToolbox toolbox;
    late MockAgent agent;

    setUp(() {
      policy = PermissionPolicy();
      toolbox = TestToolbox(policy);
      session = AgentSession(
        currentProject: NoemaProject(
          id: 'test',
          idea: 'test idea',
          story: Story(title: 'test', scenes: []),
        ),
        currentGoal: 'write a story',
      );
      agent = MockAgent(toolbox: toolbox, permissionPolicy: policy);
    });

    test('terminates when task_complete is executed', () async {
      agent.plansToReturn = [
        AgentPlan(
          goal: session.currentGoal,
          steps: [
            AgentStep(
              id: '1',
              description: 'Done',
              action: AgentAction(
                toolId: 'task_complete',
                riskLevel: ToolRiskLevel.safe,
                arguments: {'message': 'All done'},
              ),
            ),
          ],
        )
      ];

      await agent.run(session);
      
      expect(agent.formulationCalls, 1);
      expect(session.executedActions.length, 0); // executeAction returns before adding to executedActions for task_complete?
      // Wait, in my executePlan: if (action.toolId == 'task_complete') return true;
      // It returns true BEFORE adding to executedActions and results.
    });

    test('respects maxIterations', () async {
      final infinitePlan = AgentPlan(
        goal: session.currentGoal,
        steps: [
          AgentStep(
            id: '1',
            description: 'Read',
            action: AgentAction(
              toolId: 'read_project',
              riskLevel: ToolRiskLevel.safe,
              arguments: {},
            ),
          ),
        ],
      );
      agent.plansToReturn = [infinitePlan, infinitePlan, infinitePlan, infinitePlan];

      await agent.run(session, maxIterations: 3);
      
      expect(agent.formulationCalls, 3);
      expect(session.executedActions.length, 3);
      expect(session.observationHistory.any((o) => o.contains('Iteration 3')), isTrue);
    });

    test('terminates when empty plan is returned', () async {
      agent.plansToReturn = [
        AgentPlan(goal: session.currentGoal, steps: []),
      ];

      await agent.run(session);
      
      expect(agent.formulationCalls, 1);
      expect(session.observationHistory.last, contains('Plan formulated with 0 steps'));
    });
  });
}
