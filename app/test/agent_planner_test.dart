import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/llm_client.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'agent_execution_test.dart' show MockToolbox;
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';

class TestToolbox extends MockToolbox {
  TestToolbox(super.policy);

  @override
  List<AgentToolSchema> getAvailableTools() {
    return [
      AgentToolSchema(
        id: 'generate_story',
        description: 'Generates a story',
        parameters: {'idea': 'string'},
        riskLevel: ToolRiskLevel.high,
      ),
      AgentToolSchema(
        id: 'read_project',
        description: 'Reads the project',
        parameters: {},
        riskLevel: ToolRiskLevel.moderate,
      ),
      AgentToolSchema(
        id: 'generate_scene',
        description: 'Generates a scene',
        parameters: {'idea': 'string', 'mood': 'string'},
        requiredParameters: ['idea'],
        riskLevel: ToolRiskLevel.high,
      ),
    ];
  }
}

void main() {
  group('AgentPlanner JSON parsing', () {
    late AgentSession session;
    late PermissionPolicy policy;
    late TestToolbox toolbox;

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
    });

    test('successfully parses valid JSON response', () async {
      final validJson = '''
      ```json
      [
        {
          "id": "step_1",
          "description": "Read project state",
          "action": {
            "toolId": "read_project",
            "arguments": {}
          }
        },
        {
          "id": "step_2",
          "description": "Generate a new story",
          "action": {
            "toolId": "generate_story",
            "arguments": {
              "idea": "A sci-fi adventure"
            }
          }
        }
      ]
      ```
      ''';

      final llmClient = MockLlmClient(validJson);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);

      final plan = await planner.formulatePlan(session);

      expect(plan.steps.length, 2);

      expect(plan.steps[0].id, 'step_1');
      expect(plan.steps[0].action.toolId, 'read_project');
      expect(
        plan.steps[0].action.riskLevel,
        ToolRiskLevel.moderate,
      ); // default for non-generative

      expect(plan.steps[1].id, 'step_2');
      expect(plan.steps[1].action.toolId, 'generate_story');
      expect(plan.steps[1].action.arguments['idea'], 'A sci-fi adventure');
      expect(
        plan.steps[1].action.riskLevel,
        ToolRiskLevel.high,
      ); // starts with generate_
    });

    test('throws FormatException on invalid JSON', () async {
      final invalidJson = '''
      [
        {
          "id": "step_1",
          "description": "Read project state",
          "action": { // missing closing brace
        }
      ]
      ''';

      final llmClient = MockLlmClient(invalidJson);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);

      await expectLater(
        planner.formulatePlan(session),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'throws FormatException on schema mismatch (missing action)',
      () async {
        final invalidSchemaJson = '''
      [
        {
          "id": "step_1",
          "description": "Read project state"
        }
      ]
      ''';

        final llmClient = MockLlmClient(invalidSchemaJson);
        final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);

        await expectLater(
          planner.formulatePlan(session),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Missing or invalid "action" field'),
            ),
          ),
        );
      },
    );

    test('throws FormatException on duplicate step IDs', () async {
      final json = '''
      [
        {
          "id": "step_1",
          "description": "Read project state",
          "action": {
            "toolId": "read_project",
            "arguments": {}
          }
        },
        {
          "id": "step_1",
          "description": "Read again",
          "action": {
            "toolId": "read_project",
            "arguments": {}
          }
        }
      ]
      ''';
      final llmClient = MockLlmClient(json);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);
      await expectLater(
        planner.formulatePlan(session),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Duplicate step ID'),
          ),
        ),
      );
    });

    test('accepts missing optional parameters', () async {
      final json = '''
      [
        {
          "id": "step_1",
          "description": "Generate scene",
          "action": {
            "toolId": "generate_scene",
            "arguments": {
              "idea": "A dark forest"
            }
          }
        }
      ]
      ''';
      final llmClient = MockLlmClient(json);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);
      final plan = await planner.formulatePlan(session);
      expect(plan.steps.length, 1);
      expect(plan.steps.first.action.arguments['mood'], isNull);
    });

    test('throws FormatException on missing required parameter', () async {
      final json = '''
      [
        {
          "id": "step_1",
          "description": "Generate scene",
          "action": {
            "toolId": "generate_scene",
            "arguments": {
              "mood": "dark"
            }
          }
        }
      ]
      ''';
      final llmClient = MockLlmClient(json);
      final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);
      await expectLater(
        planner.formulatePlan(session),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Missing required argument "idea"'),
          ),
        ),
      );
    });
  });
}
