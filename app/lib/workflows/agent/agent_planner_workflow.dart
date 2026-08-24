import '../../core/workflow/workflow.dart';
import '../../core/workflow/workflow_step.dart';
import '../../core/workflow/workflow_context.dart';
import '../../core/providers/llm_provider.dart';
import '../../core/agent/agent_prompt_templates.dart';
import '../../core/utils/json_extractor.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:developer' as developer;

class AgentPlannerWorkflow extends Workflow {
  final LLMProvider provider;

  AgentPlannerWorkflow(this.provider)
    : super(
        id: "agent_planner",
        name: "Agent Planner Workflow",
        steps: [_AgentPlanningStep(provider)],
      );
}

class _AgentPlanningStep implements WorkflowStep {
  final LLMProvider provider;

  _AgentPlanningStep(this.provider);

  @override
  String get id => "agent_planning";

  @override
  String get name => "Agent Planning";

  @override
  Future<dynamic> execute(WorkflowContext context) async {
    final idea = context.get<String>("idea")!;

    // Simple Chunking Logic (Split by 10,000 characters to stay within context limits safely)
    final chunkSize = 10000;
    final chunks = <String>[];

    for (int i = 0; i < idea.length; i += chunkSize) {
      chunks.add(idea.substring(i, min(i + chunkSize, idea.length)));
    }

    List<Map<String, dynamic>> allScenes = [];
    String storyTitle = "Generated Story";

    String narrativeContext = "";

    for (int i = 0; i < chunks.length; i++) {
      final prompt = AgentPromptTemplates.buildChunkPrompt(
        chunks[i],
        i,
        chunks.length,
        narrativeContext: narrativeContext,
      );
      final fullPrompt =
          "${AgentPromptTemplates.sceneBreakdownSystem}\n\n$prompt";

      final response = await provider.generate(fullPrompt);
      print("RAW LLM OUTPUT: $response");

      final cleanJson = JsonExtractor.extract(response);
      print("CLEANED JSON: $cleanJson");
      final decoded = _safeDecode(cleanJson);

      if (decoded != null) {
        if (decoded.containsKey("title") && i == 0) {
          storyTitle = decoded["title"];
        }

        if (decoded.containsKey("scenes")) {
          final chunkScenes = List<Map<String, dynamic>>.from(
            decoded["scenes"].map((s) {
              if (s["characterPositions"] != null) {
                s["characterPositions"] = Map<String, String>.from(
                  s["characterPositions"],
                );
              }
              return s;
            }),
          );
          allScenes.addAll(chunkScenes);
          
          // Build narrative context for the next chunk
          if (chunkScenes.isNotEmpty) {
            final lastScene = chunkScenes.last;
            narrativeContext = "Last scene ended with: ${lastScene['description']}. Characters present: ${(lastScene['characterNames'] as List?)?.join(', ') ?? 'None'}. Mood: ${lastScene['mood']}.";
          }
        }
      }
    }

    return {"title": storyTitle, "scenes": allScenes};
  }

  Map<String, dynamic>? _safeDecode(String jsonStr) {
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      developer.log("JSON Decode Error in Agent: $e");
      return null;
    }
  }
}
