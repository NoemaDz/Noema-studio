import '../../noema_project.dart';
import '../../../models/scene.dart';
import '../../cancellation_token.dart';

/// Contract for all pipeline stages.
///
/// PRIORITY GUIDE:
///   0–49  → Planning stages (sequential: planner, characters, prompts)
///   50–69 → Per-scene production stages (parallel: image, audio)
///   70+   → Compilation stages (sequential: video export)
abstract class PipelineStage {
  /// Execution order. Lower = runs first.
  int get priority => 0;

  /// Whether this stage requires intensive GPU usage (e.g. Image/Video generation).
  /// Used by PipelineEngine to limit concurrency and prevent VRAM exhaustion.
  bool get requiresGPU => false;

  /// Token to check for cancellation during long-running tasks.
  CancellationToken? cancellationToken;

  /// Run this stage over the entire [project].
  /// Used for planning and compilation stages.
  Future<void> run(NoemaProject project);

  /// Run this stage for a single [scene] within the [project].
  /// Default implementation calls [run] (for backward compatibility).
  /// Per-scene stages (priority 50–69) SHOULD override this for parallelism.
  Future<void> runForScene(NoemaProject project, Scene scene) async {
    await run(project);
  }
}
