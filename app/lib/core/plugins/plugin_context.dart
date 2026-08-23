import '../providers/provider_registry.dart';
import '../pipeline/pipeline_registry.dart';
import '../workflow/workflow_engine.dart';

class PluginContext {
  final ProviderRegistry providers;
  final PipelineRegistry pipelines;
  final WorkflowEngine engine;

  PluginContext({
    required this.providers,
    required this.pipelines,
    required this.engine,
  });
}
