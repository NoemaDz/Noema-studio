import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/llm_agent.dart';
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/llm_client.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'agent_planner_test.dart' show TestToolbox;
import 'package:noema_studio/agent/permissions/agent_permission.dart';
import 'package:noema_studio/agent/permissions/permission_scope.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';

void main() {
  group('LlmAgent E2E execution', () {
    late AgentSession session;
    late PermissionPolicy policy;
    late TestToolbox toolbox;
    int permissionRequests = 0;
    PermissionOutcome nextPermissionResponse = PermissionOutcome.allow;

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
      permissionRequests = 0;
      nextPermissionResponse = PermissionOutcome.allow;
    });

    test('formulates and executes a plan from LLM', () async {
      final validJson = '''
      [
        {
          "id": "1",
          "description": "Generate a new story",
          "action": {
            "toolId": "generate_story",
            "arguments": {
              "idea": "A short film"
            }
          }
        }
      ]
      ''';

      final llmClient = MockLlmClient(validJson);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);

      final agent = LlmAgent(
        toolbox: toolbox,
        permissionPolicy: policy,
        planner: planner,
        onPermissionRequested: (action) async {
          permissionRequests++;
          if (nextPermissionResponse == PermissionOutcome.allow) {
            policy.grant(
              AgentPermission(
                toolId: action.toolId,
                scope: PermissionScope.once,
                grantedAt: DateTime.now(),
              ),
            );
          }
          return nextPermissionResponse;
        },
      );

      final plan = await agent.formulatePlan(session);
      expect(plan.steps.length, 1);

      await agent.executePlan(session, plan);

      expect(permissionRequests, 1);
      expect(session.executedActions.length, 1);
      expect(session.executedActions.first.toolId, 'generate_story');
    });
  });
}
