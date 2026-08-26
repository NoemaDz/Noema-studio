import '../../workflow/workflow_engine.dart';
import '../../workflow/workflow_context.dart';
import '../../providers/llm_provider.dart';
import '../contracts/pipeline_stage.dart';
import '../../../workflows/agent/agent_planner_workflow.dart';
import '../../noema_project.dart';
import '../../../models/scene.dart';
import '../../../models/story.dart';
import '../../../models/scene_directive.dart';
import '../../../models/character.dart';

class AgentPlannerStage extends PipelineStage {
  @override
  int get priority => 5; // Runs before everything else

  final WorkflowEngine engine;
  final LLMProvider provider;

  AgentPlannerStage({required this.engine, required this.provider});

  @override
  Future<void> run(NoemaProject project) async {
    // Determine if we should use Agent Planner.
    // For now, let's assume if idea is very long or if a flag is set, we use it.
    // We'll just run it always as a replacement for StoryStage for this phase.

    final workflow = AgentPlannerWorkflow(provider);
    final context = WorkflowContext();

    context.set("idea", project.idea);

    final result = await engine.runWithContext(workflow, context);

    final planningData =
        result.get<Map<String, dynamic>>("agent_planning") ?? {};
    final title = planningData["title"] as String? ?? "AI Director Story";
    final scenesData = planningData["scenes"] as List<dynamic>? ?? [];

    final List<Scene> scenes = [];
    final List<SceneDirective> directives = [];

    int sceneId = 1;
    for (final s in scenesData) {
      if (s is Map<String, dynamic>) {
        List<DialogueLine> parsedDialogue = [];
        if (s["dialogue"] != null && s["dialogue"] is List) {
          parsedDialogue = (s["dialogue"] as List)
              .map((e) => DialogueLine.fromJson(e))
              .toList();
        }

        final scene = Scene(
          id: sceneId++,
          description: s["description"] ?? "No description",
          imagePrompt: s["imagePrompt"],
          dialogue: parsedDialogue,
          narration: s["narration"],
          characterNames: List<String>.from(s["characterNames"] ?? []),
          characterPositions: s["characterPositions"] != null
              ? Map<String, String>.from(s["characterPositions"])
              : const {},
          mood: s["mood"],
          cameraEffect: s["cameraEffect"],
          colorGrading: s["colorGrading"],
          transition: s["transition"],
        );

        scenes.add(scene);

        // For SceneDirective, we might want to just store the scene itself,
        // as the actual dialogue lines will be processed by SceneAudioStage later.
        // We'll keep voiceoverText for narration or fallback.
        final voiceoverText = scene.narration ?? "";

        directives.add(
          SceneDirective(
            scene: scene,
            imagePrompt: scene.imagePrompt ?? scene.description,
            voiceoverText: voiceoverText.isNotEmpty ? voiceoverText : null,
            cameraEffect: scene.cameraEffect,
          ),
        );
      }
    }

    // Parse and store characters
    final charactersData = planningData["characters"] as List<dynamic>? ?? [];
    final List<Character> characters = [];
    int charId = 1;
    for (final c in charactersData) {
      if (c is Map<String, dynamic>) {
        characters.add(Character(
          id: 'char_${charId++}',
          name: c["name"] ?? "Unknown",
          description: c["description"] ?? "",
          prompt: c["prompt"] ?? "",
          voiceProfile: c["voiceProfile"],
        ));
      }
    }

    project.story = Story(title: title, scenes: scenes);
    
    // Completely replace existing characters with Director's Cast
    project.characters.clear();
    project.characters.addAll(characters);

    // Store directives in metadata so the next stages (AgentExecutor) can use them.
    project.metadata["agent_directives"] = directives
        .map((d) => d.toJson())
        .toList();
  }
}
