import 'dart:convert';
import 'llm_client.dart';
import 'agent_toolbox.dart';
import 'models/agent_plan.dart';
import 'models/agent_step.dart';
import 'models/agent_session.dart';
import 'models/agent_action.dart';
import 'permissions/tool_risk_level.dart';

class AgentPlanner {
  final LlmClient llmClient;
  final AgentToolbox toolbox;

  AgentPlanner({required this.llmClient, required this.toolbox});

  Future<AgentPlan> formulatePlan(AgentSession session) async {
    final prompt = _buildPrompt(session);

    final responseText = await llmClient.generateText(prompt);

    return _parseAndValidateResponse(responseText, session.currentGoal);
  }

  String _buildPrompt(AgentSession session) {
    final tools = toolbox.getAvailableTools();
    final toolsJson = jsonEncode(tools.map((t) => t.toJson()).toList());

    return '''
You are an intelligent agent planner. Your task is to break down the user's goal into a structured plan using only the available tools.

Goal: ${session.currentGoal}

Available Tools:
$toolsJson

Respond ONLY with a valid JSON array of step objects. Each step object MUST have the following structure:
{
  "id": "string (unique identifier for the step)",
  "description": "string (brief explanation of what this step does)",
  "action": {
    "toolId": "string (must match an available tool id)",
    "arguments": {
      "key": "value (parameters required by the tool)"
    }
  }
}
''';
  }

  AgentPlan _parseAndValidateResponse(String responseText, String goal) {
    // 1. Strip potential markdown code blocks
    String jsonString = responseText.trim();
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
    }
    jsonString = jsonString.trim();

    // 2. Parse JSON
    List<dynamic> jsonArray;
    try {
      jsonArray = jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      throw FormatException('LLM response is not valid JSON array: $e');
    }

    // 3. Validate schema
    final steps = <AgentStep>[];
    for (final item in jsonArray) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Each step must be a JSON object');
      }

      final id = item['id'];
      final description = item['description'];
      final actionData = item['action'];

      if (id == null || id is! String) {
        throw const FormatException('Missing or invalid "id" field in step');
      }
      if (description == null || description is! String) {
        throw const FormatException(
          'Missing or invalid "description" field in step',
        );
      }
      if (actionData == null || actionData is! Map<String, dynamic>) {
        throw const FormatException(
          'Missing or invalid "action" field in step',
        );
      }

      final toolId = actionData['toolId'];
      final arguments = actionData['arguments'];

      if (toolId == null || toolId is! String) {
        throw const FormatException('Missing or invalid "toolId" in action');
      }

      // In a real application, arguments could be properly type-checked against the schema
      final Map<String, dynamic> argsMap = arguments is Map
          ? Map<String, dynamic>.from(arguments)
          : {};

      // Determine risk level (for now, default to moderate, or we can look it up if we added risk to schema)
      // We'll set a default of high to be safe, except for read-only tools
      final riskLevel =
          toolId.startsWith('generate_') || toolId == 'save_project'
          ? ToolRiskLevel.high
          : ToolRiskLevel.moderate;

      final action = AgentAction(
        toolId: toolId,
        riskLevel: riskLevel,
        arguments: argsMap,
      );

      steps.add(AgentStep(id: id, description: description, action: action));
    }

    return AgentPlan(goal: goal, steps: steps);
  }
}
