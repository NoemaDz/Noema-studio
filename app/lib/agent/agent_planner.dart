import 'dart:convert';
import 'llm_client.dart';
import 'agent_toolbox.dart';
import 'models/agent_plan.dart';
import 'models/agent_step.dart';
import 'models/agent_session.dart';
import 'models/agent_action.dart';
import 'models/project_context.dart';

class AgentPlanner {
  final LlmClient llmClient;
  final AgentToolbox toolbox;

  AgentPlanner({required this.llmClient, required this.toolbox});

  Future<AgentPlan> formulatePlan(AgentSession session) async {
    final prompt = _buildPrompt(session);

    final responseText = await llmClient.generateText(prompt);

    return _parseAndValidateResponse(responseText, session);
  }

  String _buildPrompt(AgentSession session) {
    final tools = toolbox.getAvailableTools();
    final toolsJson = jsonEncode(tools.map((t) => t.toJson()).toList());
    final projectContext = ProjectContext.fromProject(session.currentProject);
    final contextJson = jsonEncode(projectContext.toJson());
    final deniedToolsJson = jsonEncode(session.deniedTools);

    // Bounded context: last 10 observations
    final recentObservations = session.observations.length > 10
        ? session.observations.sublist(session.observations.length - 10)
        : session.observations;
    final historyJson = jsonEncode(
      recentObservations.map((o) => o.toJson()).toList(),
    );

    return '''
You are an intelligent agent planner. Your task is to break down the user's goal into a structured plan using only the available tools.

Goal: ${session.currentGoal}

Project Context:
$contextJson

Denied Tools:
$deniedToolsJson

Recent History:
$historyJson

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

  AgentPlan _parseAndValidateResponse(
    String responseText,
    AgentSession session,
  ) {
    final goal = session.currentGoal;
    String jsonString = responseText.trim();

    // Use regex to extract the JSON array if the LLM added conversational text or markdown
    final regex = RegExp(r'\[.*\]', dotAll: true);
    final match = regex.firstMatch(jsonString);
    if (match != null) {
      jsonString = match.group(0)!;
    } else {
      // Fallback in case it's somehow not matching the regex but is valid JSON
      jsonString = jsonString.trim();
    }

    // 2. Parse JSON
    List<dynamic> jsonArray;
    try {
      jsonArray = jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      throw FormatException('LLM response is not valid JSON array: $e');
    }

    // 3. Validate schema
    final steps = <AgentStep>[];
    final seenIds = <String>{};

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

      if (seenIds.contains(id)) {
        throw FormatException('Duplicate step ID found: $id');
      }
      seenIds.add(id);

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

      if (session.deniedTools.any((d) => d['toolId'] == toolId)) {
        throw FormatException('Tool is denied: $toolId');
      }

      final tools = toolbox.getAvailableTools();
      final schema = tools.firstWhere(
        (t) => t.id == toolId,
        orElse: () => throw FormatException('Unknown toolId: $toolId'),
      );

      final Map<String, dynamic> argsMap = arguments is Map
          ? Map<String, dynamic>.from(arguments)
          : {};

      // Check required parameters
      for (final key in schema.requiredParameters) {
        if (!argsMap.containsKey(key)) {
          throw FormatException(
            'Missing required argument "$key" for tool "$toolId"',
          );
        }
      }

      // Check types and unknown parameters
      for (final key in argsMap.keys) {
        if (!schema.parameters.containsKey(key)) {
          throw FormatException('Unknown argument "$key" for tool "$toolId"');
        }

        final expectedType = schema.parameters[key];
        final val = argsMap[key];
        if (expectedType == 'string' && val is! String) {
          throw FormatException(
            'Argument "$key" must be a string for tool "$toolId"',
          );
        }
      }

      final riskLevel = schema.riskLevel;

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
