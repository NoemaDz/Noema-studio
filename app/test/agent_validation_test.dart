import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/llm_client.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'agent_planner_test.dart' show TestToolbox;
import 'package:noema_studio/agent/permissions/permission_policy.dart';

void main() {
  group('AI Agent Output Validation', () {
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
        currentGoal: 'test',
      );
    });

    test('Valid output must be accepted', () async {
      final validJson = '''
      [
        {
          "id": "1",
          "description": "desc",
          "action": {
            "toolId": "generate_story",
            "arguments": {
              "idea": "some idea"
            }
          }
        }
      ]
      ''';
      final client = MockLlmClient(validJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      final plan = await planner.formulatePlan(session);
      expect(plan.steps.length, 1);
    });

    test('Empty output must be rejected safely', () async {
      final emptyJson = '[]';
      final client = MockLlmClient(emptyJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      final plan = await planner.formulatePlan(session);
      expect(plan.steps.isEmpty, isTrue);
    });

    test('Malformed JSON must produce a controlled failure', () async {
      final malformedJson = 'invalid json {';
      final client = MockLlmClient(malformedJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      expect(
        () => planner.formulatePlan(session),
        throwsA(isA<FormatException>()),
      );
    });

    test('Valid JSON with missing required fields must be rejected', () async {
      final missingFieldJson = '''
      [
        {
          "id": "1",
          "description": "desc",
          "action": {
            "toolId": "generate_story",
            "arguments": {}
          }
        }
      ]
      '''; // generate_story requires 'idea'
      final client = MockLlmClient(missingFieldJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      expect(
        () => planner.formulatePlan(session),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Missing required argument "idea"'),
          ),
        ),
      );
    });

    test('Wrong data types must be rejected', () async {
      final wrongTypeJson = '''
      [
        {
          "id": "1",
          "description": "desc",
          "action": {
            "toolId": "generate_story",
            "arguments": {
              "idea": 123
            }
          }
        }
      ]
      ''';
      final client = MockLlmClient(wrongTypeJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      expect(
        () => planner.formulatePlan(session),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must be a string'),
          ),
        ),
      );
    });

    test('Unexpected additional data must be rejected', () async {
      final unexpectedDataJson = '''
      [
        {
          "id": "1",
          "description": "desc",
          "action": {
            "toolId": "generate_story",
            "arguments": {
              "idea": "some idea",
              "unknown_field": "test"
            }
          }
        }
      ]
      ''';
      final client = MockLlmClient(unexpectedDataJson);
      final planner = AgentPlanner(llmClient: client, toolbox: toolbox);

      expect(
        () => planner.formulatePlan(session),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown argument "unknown_field"'),
          ),
        ),
      );
    });
  });
}
