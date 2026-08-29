import '../project_synchronizer.dart';
import '/models/task.dart';
import '/core/noema_project.dart';
import 'project_service.dart';
import '/core/job_monitor.dart';
import '/core/providers/image_provider.dart';
import '/core/job_events.dart';
import '/core/pipeline/project_pipeline.dart';
import '../../core/cancellation_token.dart';
import '../../presentation/state/project_state.dart';
import '../../core/providers/provider_registry.dart';
import '../../core/job_manager.dart';

class ProjectGenerationService {
  final ProjectPipeline projectPipeline;

  final ProjectService projectService;

  final JobMonitor jobMonitor;

  final ImageProvider imageProvider;

  final JobEvents jobEvents;

  final ProjectState projectState;

  final ProviderRegistry providerRegistry;
  final JobManager jobManager;
  final Future<void> Function(NoemaProject) saveProject;

  ProjectGenerationService({
    required this.projectPipeline,
    required this.projectService,
    required this.jobMonitor,
    required this.imageProvider,
    required this.jobEvents,
    required this.projectState,
    required this.providerRegistry,
    required this.jobManager,
    required this.saveProject,
  });

  Future<NoemaProject> generatePlanning(NoemaProject project) async {
    // Start job monitor so that Character image generation jobs can be tracked
    jobMonitor.start();

    await projectPipeline.generatePlanning(
      project,
      onUpdate: (status) {
        projectState.setPipelineStatus(status);
      },
    );
    await projectService.runTask(
      project: project,
      type: TaskType.extractCharacters,
      action: () async {},
    );
    await projectService.runTask(
      project: project,
      type: TaskType.generateCharacterImages,
      action: () async {},
    );
    await projectService.runTask(
      project: project,
      type: TaskType.buildScenePrompts,
      action: () async {},
    );
    return project;
  }

  Future<NoemaProject> generateProduction(NoemaProject project, {CancellationToken? cancellationToken, Function(String)? onUpdate}) async {
    final synchronizer = ProjectSynchronizer(
      project: project,
      registry: providerRegistry,
      state: projectState,
      jobManager: jobManager,
      saveProject: saveProject,
    );
    await synchronizer.attach(jobEvents);
    jobMonitor.start();

    await projectPipeline.generateProduction(
      project,
      cancellationToken: cancellationToken,
      onUpdate: (status) {
        projectState.setPipelineStatus(status);
        if (onUpdate != null) {
          onUpdate(status);
        }
      },
    );

    await projectService.runTask(
      project: project,
      type: TaskType.generateSceneImages,
      action: () async {},
    );
    await saveProject(project);
    return project;
  }
}
