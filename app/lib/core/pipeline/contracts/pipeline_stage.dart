import '../../noema_project.dart';

abstract class PipelineStage {
  int get priority => 0;

  Future<void> run(
    NoemaProject project,
  );
}