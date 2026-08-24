import '../providers/provider_registry.dart';
import '../pipeline/pipeline_registry.dart';
import '../workflow/workflow_engine.dart';
import '../settings/app_settings.dart';
import '../job_manager.dart';

class PluginContext {
  final ProviderRegistry providers;
  final PipelineRegistry pipelines;
  final WorkflowEngine engine;
  final AppSettings appSettings;
  final JobManager jobManager;

  PluginContext({
    required this.providers,
    required this.pipelines,
    required this.engine,
    required this.appSettings,
    required this.jobManager,
  });
}
