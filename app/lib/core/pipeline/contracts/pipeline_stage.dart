import '../../noema_project.dart';
import '../../../models/scene.dart';

/// Contract for all pipeline stages.
///
/// PRIORITY GUIDE:
///   0–49  → Planning stages (sequential: planner, characters, prompts)
///   50–69 → Per-scene production stages (parallel: image, audio)
///   70+   → Compilation stages (sequential: video export)
abstract class PipelineStage {
  /// Execution order. Lower = runs first.
  int get priority => 0;

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