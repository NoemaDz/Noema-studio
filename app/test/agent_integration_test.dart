import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:noema_studio/agent/llm_agent.dart';
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/permissions/permission_scope.dart';
import 'package:noema_studio/agent/permissions/agent_permission.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/infrastructure/ollama/ollama_llm_client.dart';
import 'agent_planner_test.dart' show TestToolbox;
import 'ollama_llm_client_test.dart' show MockHttpClient;

void main() {
  group('Full Agent Integration Pipeline', () {
    late AgentSession session;
    late PermissionPolicy policy;
    late TestToolbox toolbox;

    setUp(() {
      policy = PermissionPolicy();
      toolbox = TestToolbox(policy);
      session = AgentSession(
        currentProject: NoemaProject(
          id: 'proj_123',
          idea: 'test idea',
          story: Story(title: 'test', scenes: []),
        ),
        currentGoal: 'write a story',
      );
    });

    test(
      'User Goal -> OllamaLlmClient -> JSON -> AgentPlanner -> AgentPlan -> execution',
      () async {
        // 1. Mock the Ollama HTTP layer
        final validJson = '''
      [
        {
          "id": "step_1",
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

        final mockHttpClient = MockHttpClient((request) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'response': validJson}))),
            200,
          );
        });

        // 2. Wire the real OllamaLlmClient to the Mock HTTP client
        final llmClient = OllamaLlmClient(
          baseUrl: 'http://localhost:11434',
          modelName: 'llama3',
          client: mockHttpClient,
        );

        // 3. Wire AgentPlanner to the OllamaLlmClient
        final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);

        int permissionRequests = 0;

        // 4. Wire LlmAgent to the AgentPlanner
        final agent = LlmAgent(
          toolbox: toolbox,
          permissionPolicy: policy,
          planner: planner,
          onPermissionRequested: (action) async {
            permissionRequests++;
            policy.grant(
              AgentPermission(
                toolId: action.toolId,
                scope: PermissionScope.once,
                grantedAt: DateTime.now(),
              ),
            );
            return true;
          },
        );

        // 5. Test Formulation Flow
        final plan = await agent.formulatePlan(session);

        expect(plan.steps.length, 1);
        expect(plan.steps.first.id, 'step_1');
        expect(plan.steps.first.action.toolId, 'generate_story');

        // 6. Test Execution Flow
        await agent.executePlan(session, plan);

        expect(permissionRequests, 1);
        expect(session.executedActions.length, 1);
        expect(session.executedActions.first.toolId, 'generate_story');
      },
    );
  });
}
