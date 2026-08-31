import 'workflow/workflow_engine.dart';
import 'cancellation_token.dart';
import 'noema_project.dart';
import '../models/job.dart';
import 'bootstrap.dart';
import 'plugins/plugin_interface.dart';
import '/application/services/project_generation_service.dart';
import '/application/services/project_persistence_service.dart';
import '/application/services/story_generation_service.dart';
import '/application/services/image_generation_service.dart';
import '/application/services/character_extraction_service.dart';
import '/application/services/document_ingestion_service.dart';
import 'dart:io';

class Noema {
  final Bootstrap bootstrap;
  final WorkflowEngine engine = WorkflowEngine();

  ProjectGenerationService get projectGenerationService =>
      bootstrap.projectGenerationService;
  ProjectPersistenceService get projectPersistenceService =>
      bootstrap.projectPersistenceService;
  StoryGenerationService get storyGenerationService =>
      bootstrap.storyGenerationService;
  ImageGenerationService get imageGenerationService =>
      bootstrap.imageGenerationService;
  CharacterExtractionService get characterExtractionService =>
      bootstrap.characterExtractionService;
  DocumentIngestionService get documentIngestionService =>
      bootstrap.documentIngestionService;

  Noema({Bootstrap? bootstrap}) : bootstrap = bootstrap ?? Bootstrap();

  void init(List<IPlugin> plugins) {
    bootstrap.initializePlugins(plugins);
  }

  Future<String> generateStory(String idea) {
    return storyGenerationService.generateStory(idea);
  }

  //===========================================================
  Future<Job> generateImage(String prompt) {
    return imageGenerationService.generateImage(prompt);
  }

  //===========================================================
  Future<NoemaProject> generateProject(NoemaProject project) async {
    await projectGenerationService.generatePlanning(project);
    return projectGenerationService.generateProduction(project);
  }

  //==================================================
  Future<void> extractCharacters(NoemaProject project) {
    return characterExtractionService.extractCharacters(project);
  }

  //==============================================
  Future<NoemaProject> generatePlanning(NoemaProject project) {
    return projectGenerationService.generatePlanning(project);
  }

  Future<NoemaProject> generateProduction(
    NoemaProject project, {
    CancellationToken? cancellationToken,
    Function(String)? onUpdate,
  }) {
    return projectGenerationService.generateProduction(
      project,
      cancellationToken: cancellationToken,
      onUpdate: onUpdate,
    );
  }

  //===========================================
  Future<void> saveProject(NoemaProject project) {
    return projectPersistenceService.saveProject(project);
  }

  //===========================================
  Future<NoemaProject> openProject(String path) async {
    final project = await projectPersistenceService.openProject(path);

    // 1. Native Job Recovery
    if (project.savedJobs.isNotEmpty) {
      bootstrap.jobManager.restoreJobs(project.savedJobs);
    }

    // 2. Artifact Filesystem Reconciliation
    // Remove any artifacts that no longer exist on disk
    project.artifacts.removeWhere(
      (artifact) => !File(artifact.path).existsSync(),
    );

    for (var img in project.images) {
      if (img.artifact != null && !File(img.artifact!.path).existsSync())
        img.artifact = null;
    }
    for (var vid in project.videos) {
      if (vid.artifact != null && !File(vid.artifact!.path).existsSync())
        vid.artifact = null;
    }
    for (var aud in project.audios) {
      if (aud.artifact != null && !File(aud.artifact!.path).existsSync())
        aud.artifact = null;
    }

    if (project.finalVideoPath != null &&
        !File(project.finalVideoPath!).existsSync()) {
      project.finalVideoPath = null;
    }

    return project;
  }

  //=========================================
}
