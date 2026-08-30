import '../noema_project.dart';
import '../../models/generation_state.dart';
import 'pipeline_registry.dart';
import 'task_node.dart';
import 'pipeline_engine.dart';
import 'contracts/pipeline_stage.dart';
import '../../models/job.dart';
import '../cancellation_token.dart';
import '../job_manager.dart';

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
  final JobManager jobManager;

  ProjectPipeline({
    required this.registry,
    required this.jobManager,
    PipelineEngine? engine,
  }) : engine =
           engine ??
           PipelineEngine(maxConcurrentTasks: 4, maxConcurrentGPUTasks: 1);

  /// Runs the initial planning phases (Story, Characters, Scene Prompts).
  /// This stops before any heavy generation happens.
  Future<NoemaProject> generatePlanning(
    NoemaProject project, {
    void Function(String status)? onUpdate,
    CancellationToken? cancellationToken,
  }) async {
    final planningStages = _stagesInRange(0, 50);

    project.projectState = GenerationState.planning;

    // ── Phase 1: Sequential planning ──────────────────────────────────────
    for (final stage in planningStages) {
      cancellationToken?.throwIfCancelled();
      final name = stage.runtimeType.toString();
      onUpdate?.call('[$name] planning...');
      stage.cancellationToken = cancellationToken;
      await stage.run(project);
      onUpdate?.call('[$name] done ✓');
    }

    // Move to review state
    project.projectState = GenerationState.reviewing;
    return project;
  }

  /// Runs the production phases (Images, Audio, Video Compilation).
  /// This should be called AFTER the user has reviewed and manually edited the planning results.
  Future<NoemaProject> generateProduction(
    NoemaProject project, {
    void Function(String status)? onUpdate,
    CancellationToken? cancellationToken,
  }) async {
    final sceneStages = _stagesInRange(50, 70);
    final compilationStages = _stagesInRange(70, 999);

    project.projectState = GenerationState.generating;

    // Clear previous media if regenerating (only clear those that are not completed)
    project.images.removeWhere((img) {
      final scene = project.story.scenes
          .where((s) => s.id == img.sceneId)
          .firstOrNull;
      return scene == null ||
          scene.imageState != GenerationState.completed ||
          scene.imagePath == null;
    });
    project.audios.removeWhere((aud) {
      final scene = project.story.scenes
          .where((s) => s.id == aud.sceneId)
          .firstOrNull;
      return scene == null || scene.audioState != GenerationState.completed;
    });
    // Keep pending jobs clean
    final jobsToRemove = jobManager.jobs
        .where(
          (j) =>
              project.jobIds.contains(j.id) &&
              (j.status == JobStatus.pending ||
                  j.status == JobStatus.running ||
                  j.status == JobStatus.failed),
        )
        .map((j) => j.id)
        .toList();

    for (final jobId in jobsToRemove) {
      jobManager.remove(jobId);
      project.jobIds.remove(jobId);
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
            requiresGPU: stage.requiresGPU,
            execute: () async {
              onUpdate?.call('[Scene ${scene.id}] $stageName...');
              stage.cancellationToken = cancellationToken;
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
        cancellationToken: cancellationToken,
      );
    }

    // ── Phase 3: Sequential compilation ───────────────────────────────────
    for (final stage in compilationStages) {
      cancellationToken?.throwIfCancelled();
      final name = stage.runtimeType.toString();
      onUpdate?.call('[$name] compiling...');
      stage.cancellationToken = cancellationToken;
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
