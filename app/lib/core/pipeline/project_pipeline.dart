import '../noema_project.dart';
import '../../models/generation_state.dart';
import 'pipeline_registry.dart';
import 'task_node.dart';
import 'pipeline_engine.dart';
import 'contracts/pipeline_stage.dart';

/// Converts registered [PipelineStage]s into a true DAG of [TaskNode]s
/// and executes them via [PipelineEngine].
///
/// ┌──────────────────────────────────────────────────────────┐
/// │  EXECUTION CONTRACT                                       │
/// │  Workflow  = "What does the AI DO?" (LLM calls, prompts) │
/// │  Pipeline  = "In what ORDER?" (DAG dependency graph)     │
/// │  Job       = "Track background work" (ComfyUI polling)   │
/// └──────────────────────────────────────────────────────────┘
///
/// DAG STRUCTURE (true per-scene parallelism):
///
///   [AgentPlanner] → [CharacterStage] → [CharacterImageStage]
///                                               │
///             ┌─────────────────────────────────┘
///             │
///     ┌───────┴────────┐
///     ▼    (parallel)  ▼
///  [SceneImage_1] [SceneImage_2] ... [SceneImage_N]
///     │                │
///     ▼    (join)      ▼
///  [SceneAudio_1] [SceneAudio_2] ... [SceneAudio_N]
///             │
///             └──────────────► [VideoCompilation]
class ProjectPipeline {
  final PipelineRegistry registry;
  final PipelineEngine engine;

  ProjectPipeline({required this.registry, PipelineEngine? engine})
    : engine = engine ?? PipelineEngine(maxConcurrentTasks: 2);

  Future<NoemaProject> generate(
    NoemaProject project, {
    void Function(String status)? onUpdate,
  }) async {
    // ── Classify stages by priority ────────────────────────────────────────
    // priority < 50  → planning (must run sequentially before we know scenes)
    // 50 ≤ priority < 70 → per-scene production (image + audio, run in parallel)
    // priority ≥ 70  → final compilation (sequential, after all scenes done)
    final planningStages = _stagesInRange(0, 50);
    final sceneStages = _stagesInRange(50, 70);
    final compilationStages = _stagesInRange(70, 999);

    // ── Phase 1: Sequential planning ──────────────────────────────────────
    for (final stage in planningStages) {
      final name = stage.runtimeType.toString();
      onUpdate?.call('[$name] planning...');
      await stage.run(project);
      onUpdate?.call('[$name] done ✓');
    }

    // ── Phase 2: Per-scene parallel DAG ───────────────────────────────────
    if (sceneStages.isNotEmpty && project.story.scenes.isNotEmpty) {
      final allNodes = <TaskNode>[];
      List<TaskNode> previousGroupJoiners = []; // empty = no dependencies

      for (int stageIdx = 0; stageIdx < sceneStages.length; stageIdx++) {
        final stage = sceneStages[stageIdx];
        final stageName = stage.runtimeType.toString();
        final List<TaskNode> thisGroupNodes = [];

        for (final scene in project.story.scenes) {
          final node = TaskNode(
            id: '${stageName}_${scene.id}',
            name: '$stageName [Scene ${scene.id}]',
            execute: () async {
              onUpdate?.call('[Scene ${scene.id}] $stageName...');
              await stage.runForScene(project, scene);
              onUpdate?.call('[Scene ${scene.id}] $stageName ✓');
            },
            // This scene-node depends on ALL joiners from the previous group,
            // ensuring every scene in the previous stage finishes first.
            dependencies: List.from(previousGroupJoiners),
          );
          thisGroupNodes.add(node);
          allNodes.add(node);
        }

        // Create a joiner node that depends on ALL scene nodes in this group.
        // The next stage group will depend on these joiners.
        final joiner = TaskNode(
          id: '${stageName}_join',
          name: '$stageName [All Scenes Done]',
          execute: () async {}, // no-op sentinel
          dependencies: thisGroupNodes,
        );
        allNodes.add(joiner);
        previousGroupJoiners = [joiner];
      }

      await engine.run(
        allNodes,
        onTaskUpdate: (task) {
          final status = _statusLabel(task);
          onUpdate?.call('Pipeline: ${task.name} — $status');
        },
      );
    }

    // ── Phase 3: Sequential compilation ───────────────────────────────────
    for (final stage in compilationStages) {
      final name = stage.runtimeType.toString();
      onUpdate?.call('[$name] compiling...');
      await stage.run(project);
      onUpdate?.call('[$name] done ✓');
    }

    project.projectState = GenerationState.completed;
    return project;
  }

  List<PipelineStage> _stagesInRange(int minPriority, int maxPriority) {
    return registry.stages
        .where((s) => s.priority >= minPriority && s.priority < maxPriority)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  String _statusLabel(TaskNode task) {
    if (task.isCompleted) return 'completed ✓';
    if (task.isFailed) return 'FAILED ✗';
    if (task.isRunning) return 'running...';
    return 'waiting';
  }
}
