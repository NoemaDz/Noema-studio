import 'providers/provider_registry.dart';
import 'providers/image_provider.dart';
import 'providers/llm_provider.dart';
import 'plugins/plugin_manager.dart';
import 'plugins/plugin_context.dart';
import 'plugins/plugin_interface.dart';
import 'pipeline/pipeline_registry.dart';
import 'workflow/workflow_engine.dart';
import 'job_runner.dart';
import 'job_monitor.dart';
import 'job_manager.dart';
import 'job_events.dart';
import 'pipeline/project_pipeline.dart';
import '../presentation/state/project_state.dart';
import '../application/services/project_service.dart';
import '../application/services/project_generation_service.dart';
import '../application/services/project_persistence_service.dart';
import '../application/services/story_generation_service.dart';
import '../application/services/image_generation_service.dart';
import '../application/services/character_extraction_service.dart';
import '../application/services/document_ingestion_service.dart';
import 'settings/app_settings.dart';

class Bootstrap {
  late final PluginManager pluginManager;
  late final ProviderRegistry providerRegistry;
  late final PipelineRegistry pipelineRegistry;
  late final WorkflowEngine workflowEngine;

  late final ImageProvider imageProvider;
  late final LLMProvider ollamaProvider;

  late final ProjectPipeline projectPipeline;
  late final JobRunner jobRunner;
  late final JobManager jobManager;
  late final JobMonitor jobMonitor;
  late final JobEvents jobEvents;
  late final ProjectState projectState;
  late final AppSettings appSettings;

  late final ProjectService projectService;
  late final ProjectGenerationService projectGenerationService;
  late final ProjectPersistenceService projectPersistenceService;
  late final StoryGenerationService storyGenerationService;
  late final ImageGenerationService imageGenerationService;
  late final CharacterExtractionService characterExtractionService;
  late final DocumentIngestionService documentIngestionService;

  Bootstrap() {
    providerRegistry = ProviderRegistry();
    pipelineRegistry = PipelineRegistry();
    workflowEngine = WorkflowEngine();
    appSettings = AppSettings();

    final pluginContext = PluginContext(
      providers: providerRegistry,
      pipelines: pipelineRegistry,
      engine: workflowEngine,
    );

    pluginManager = PluginManager(context: pluginContext);
  }

  void initializePlugins(List<IPlugin> plugins) {
    pluginManager.loadPlugins(plugins);

    imageProvider = providerRegistry.getDefault<ImageProvider>();
    ollamaProvider = providerRegistry.getDefault<LLMProvider>();

    projectPipeline = ProjectPipeline(registry: pipelineRegistry);

    storyGenerationService = StoryGenerationService(engine: workflowEngine);
    imageGenerationService = ImageGenerationService(engine: workflowEngine);
    characterExtractionService = CharacterExtractionService(
      engine: workflowEngine,
    );

    jobManager = JobManager();
    jobRunner = JobRunner(imageProvider);
    jobEvents = JobEvents();
    projectState = ProjectState();

    jobMonitor = JobMonitor(jobRunner, jobManager, jobEvents);

    projectService = ProjectService();
    projectPersistenceService = ProjectPersistenceService();

    projectGenerationService = ProjectGenerationService(
      projectPipeline: projectPipeline,
      projectService: projectService,
      jobMonitor: jobMonitor,
      imageProvider: imageProvider,
      jobEvents: jobEvents,
      projectState: projectState,
    );

    documentIngestionService = DocumentIngestionService(providerRegistry);
  }
}
