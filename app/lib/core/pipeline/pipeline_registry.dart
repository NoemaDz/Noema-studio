import 'contracts/pipeline_stage.dart';

class PipelineRegistry {
  final List<PipelineStage> _stages = [];

  void register(PipelineStage stage) {
    _stages.add(stage);
    _stages.sort((a, b) => a.priority.compareTo(b.priority));
  }

  List<PipelineStage> get stages => List.unmodifiable(_stages);
  
  void clear() {
    _stages.clear();
  }
}
