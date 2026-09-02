import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/agent.dart';
import 'package:noema_studio/agent/agent_planner.dart';
import 'package:noema_studio/agent/llm_client.dart';
import 'package:noema_studio/agent/models/agent_session.dart';
import 'package:noema_studio/agent/models/agent_plan.dart';
import 'package:noema_studio/agent/models/agent_action.dart';
import 'package:noema_studio/agent/models/permission_outcome.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/models/tool_result.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/agent/agent_toolbox.dart';
import 'package:noema_studio/agent/models/agent_tool_schema.dart';
import 'package:noema_studio/infrastructure/ollama/ollama_llm_client.dart';

class ThrowingLlmClient implements LlmClient {
  @override
  Future<String> generateText(String prompt) async {
    throw LlmTimeoutException('Simulated Timeout');
  }
}

class FakeToolbox implements AgentToolbox {
  @override
  List<AgentToolSchema> getAvailableTools() => [];

  @override
  Future<ToolResult> executeAction(
    AgentSession session,
    AgentAction action,
  ) async {
    return ToolResult(toolId: action.toolId, status: ToolResultStatus.success);
  }
}

class FakeAgent extends Agent {
  final LlmClient llmClient;

  FakeAgent({
    required super.toolbox,
    required super.permissionPolicy,
    required this.llmClient,
  });

  @override
  Future<AgentPlan> formulatePlan(AgentSession session) async {
    final planner = AgentPlanner(llmClient: llmClient, toolbox: toolbox);
    return planner.formulatePlan(session);
  }

  @override
  Future<PermissionOutcome> requestPermission(AgentAction action) async {
    return PermissionOutcome.allow;
  }
}

void main() {
  group('Agent E2E Failure Handling', () {
    late PermissionPolicy policy;
    late AgentToolbox toolbox;
    late AgentSession session;

    setUp(() {
      policy = PermissionPolicy();
      toolbox = FakeToolbox();
      session = AgentSession(
        currentProject: NoemaProject(
          id: 'test',
          idea: 'test idea',
          story: Story(title: 'test', scenes: []),
        ),
        currentGoal: 'test',
      );
    });

    test('Agent loop gracefully fails when LLM times out', () async {
      final client = ThrowingLlmClient();
      final agent = FakeAgent(
        toolbox: toolbox,
        permissionPolicy: policy,
        llmClient: client,
      );

      // This should NOT throw an unhandled exception
      await agent.run(session);

      // It should gracefully transition to failed
      expect(session.state, AgentSessionState.failed);

      // And record the error in observations
      final lastObs = session.observations.last;
      expect(lastObs.result.status, ToolResultStatus.fatalFailure);
      expect(lastObs.result.error, contains('Simulated Timeout'));
    });
  });
}
