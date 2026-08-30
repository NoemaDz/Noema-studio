import '../models/story.dart';
import 'noema_state.dart';
import '../models/generated_image.dart';
import '../models/generated_video.dart';
import '../models/generated_audio.dart';
import '../models/character.dart';
import '../models/style.dart';
import 'styles/style_registry.dart';
import '../models/project_task.dart';
import '../models/job.dart';
import '../core/project_progress.dart';
import '../core/project_statistics.dart';
import '../core/project_summary.dart';
import '../models/asset.dart';
import '../models/asset_type.dart';
import 'package:uuid/uuid.dart';
import '../models/generation_state.dart';

/// The single canonical domain model for a Noema production project.
/// This is the Source of Truth for all project state — from initial idea
/// to final video output.
///
/// ARCHITECTURE NOTE:
/// Do NOT create a parallel "Project" model. This class owns everything.
/// For UI display, use ProjectViewModel (presentation layer only).
class NoemaProject {
  final String id;

  // ── Identity ──────────────────────────────────────────────────────────────
  String title;
  String idea;
  String language;
  final DateTime createdAt;

  // ── AI Model Settings ─────────────────────────────────────────────────────
  String imageModel;
  String llmModel;

  // ── Production Stage ──────────────────────────────────────────────────────
  ProjectStage stage;

  // ── Content ───────────────────────────────────────────────────────────────
  Story story;
  Style style;
  final List<Character> characters = [];

  // ── Assets (generated outputs) ────────────────────────────────────────────
  final List<GeneratedImage> images = [];
  final List<GeneratedVideo> videos = [];
  final List<GeneratedAudio> audios = [];
  String? finalVideoPath;

  // ── Execution State ───────────────────────────────────────────────────────
  final List<ProjectTask> tasks = [];
  final List<String> jobIds = [];
  final List<Job> savedJobs = [];
  GenerationState projectState;

  // ── Meta ──────────────────────────────────────────────────────────────────
  final Map<String, dynamic> settings = {};
  final Map<String, dynamic> metadata = {};

  NoemaProject({
    required this.id,
    required this.idea,
    required this.story,
    String? title,
    this.language = 'en',
    this.imageModel = 'comfyui',
    this.llmModel = 'ollama',
    DateTime? createdAt,
    this.stage = ProjectStage.story,
    this.projectState = GenerationState.draft,
    Style? style,
  }) : title = title ?? idea,
       createdAt = createdAt ?? DateTime.now(),
       style = style ?? StyleRegistry.defaultStyle;

  // ── Computed Properties ───────────────────────────────────────────────────

  ProjectProgress get progress => ProjectProgress(tasks);

  ProjectStatistics get statistics => ProjectStatistics(this);

  ProjectSummary get summary => ProjectSummary(this);

  // ── Job Integration ───────────────────────────────────────────────────────

  void updateImageFromJob(Job job) {
    final image = images.cast<GeneratedImage?>().firstWhere(
      (e) => e?.jobId == job.id,
      orElse: () => null,
    );
    if (image == null) return;
    image.asset = Asset(
      id: job.id,
      path: job.result ?? '',
      type: AssetType.image,
    );
  }

  void updateAudioFromJob(Job job) {
    final audio = audios.cast<GeneratedAudio?>().firstWhere(
      (e) => e?.jobId == job.id,
      orElse: () => null,
    );
    if (audio == null) return;
    audio.asset = Asset(
      id: job.id,
      path: job.result ?? '',
      type: AssetType.audio,
    );
  }

  void updateVideoFromJob(Job job) {
    final video = videos.cast<GeneratedVideo?>().firstWhere(
      (e) => e?.jobId == job.id,
      orElse: () => null,
    );
    if (video == null) return;
    video.asset = Asset(
      id: job.id,
      path: job.result ?? '',
      type: AssetType.video,
    );
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'idea': idea,
      'language': language,
      'imageModel': imageModel,
      'llmModel': llmModel,
      'createdAt': createdAt.toIso8601String(),
      'stage': stage.name,
      'projectState': projectState.toJson(),
      'story': story.toJson(),
      'style': style.toJson(),
      'characters': characters.map((e) => e.toJson()).toList(),
      'images': images.map((e) => e.toJson()).toList(),
      'videos': videos.map((e) => e.toJson()).toList(),
      'audios': audios.map((e) => e.toJson()).toList(),
      'finalVideoPath': finalVideoPath,
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'jobIds': jobIds,
      'savedJobs': savedJobs.map((e) => e.toJson()).toList(),
      'settings': settings,
      'metadata': metadata,
    };
  }

  factory NoemaProject.fromJson(Map<String, dynamic> json) {
    final project = NoemaProject(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] as String?,
      idea: json['idea'] as String,
      language: json['language'] as String? ?? 'en',
      imageModel: json['imageModel'] as String? ?? 'comfyui',
      llmModel: json['llmModel'] as String? ?? 'ollama',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      story: Story.fromJson(json['story'] as Map<String, dynamic>),
      stage: ProjectStage.values.byName(
        json['stage'] as String? ?? ProjectStage.story.name,
      ),
      projectState: GenerationStateExtension.fromJson(
        json['projectState'] as String?,
      ),
      style: json['style'] != null
          ? Style.fromJson(json['style'] as Map<String, dynamic>)
          : null,
    );

    if (json['characters'] != null) {
      project.characters.addAll(
        (json['characters'] as List).map(
          (e) => Character.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    if (json['images'] != null) {
      project.images.addAll(
        (json['images'] as List).map(
          (e) => GeneratedImage.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    if (json['videos'] != null) {
      project.videos.addAll(
        (json['videos'] as List).map(
          (e) => GeneratedVideo.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    if (json['audios'] != null) {
      project.audios.addAll(
        (json['audios'] as List).map(
          (e) => GeneratedAudio.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    project.finalVideoPath = json['finalVideoPath'] as String?;

    if (json['tasks'] != null) {
      project.tasks.addAll(
        (json['tasks'] as List).map(
          (e) => ProjectTask.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    if (json['jobIds'] != null) {
      project.jobIds.addAll(List<String>.from(json['jobIds'] as List));
    }

    if (json['savedJobs'] != null) {
      project.savedJobs.addAll(
        (json['savedJobs'] as List).map(
          (e) => Job.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    if (json['settings'] != null) {
      project.settings.addAll(
        Map<String, dynamic>.from(json['settings'] as Map),
      );
    }

    if (json['metadata'] != null) {
      project.metadata.addAll(
        Map<String, dynamic>.from(json['metadata'] as Map),
      );
    }

    return project;
  }
}
