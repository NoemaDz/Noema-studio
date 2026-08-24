import '../project_synchronizer.dart';
import '/models/task.dart';
import '/core/noema_project.dart';
import 'project_service.dart';
import '/core/job_monitor.dart';
import '/core/providers/image_provider.dart';
import '/core/job_events.dart';
import '/core/pipeline/project_pipeline.dart';
import '../../presentation/state/project_state.dart';
import '../../main.dart'; // To access global noema

class ProjectGenerationService {
  final ProjectPipeline projectPipeline;

  final ProjectService projectService;

  final JobMonitor jobMonitor;

  final ImageProvider imageProvider;

  final JobEvents jobEvents;

  final ProjectState projectState;

  ProjectGenerationService({
    required this.projectPipeline,
    required this.projectService,
    required this.jobMonitor,
    required this.imageProvider,
    required this.jobEvents,
    required this.projectState,
  });

  Future<NoemaProject> generatePlanning(NoemaProject project) async {
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

  Future<NoemaProject> generateProduction(NoemaProject project) async {
    final synchronizer = ProjectSynchronizer(
      project: project,
      provider: imageProvider,
      state: projectState,
    );
    synchronizer.attach(jobEvents);
    jobMonitor.start(project.jobs);

    await projectPipeline.generateProduction(
      project,
      onUpdate: (status) {
        projectState.setPipelineStatus(status);
      },
    );

    await projectService.runTask(
      project: project,
      type: TaskType.generateSceneImages,
      action: () async {},
    );
    await noema.saveProject(project);
    return project;
  }
}
