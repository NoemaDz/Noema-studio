import '../models/story.dart';
import 'noema_state.dart';
import '../models/generated_image.dart';
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








class NoemaProject {
  final String id;
  Story story;
  String idea;

  ProjectStage stage;

  final List<GeneratedImage> images = [];
  final List<GeneratedAudio> audios = [];
  final List<Character> characters = [];
  final List<ProjectTask> tasks = [];
  final List<Job> jobs = [];

  String? finalVideoPath;

  NoemaProject({
    required this.id,
    required this.idea,
    required this.story,
    this.stage = ProjectStage.story,
  });
  
  final Map<String, dynamic> settings = {};

  final Map<String, dynamic> metadata = {};

  Style style = StyleRegistry.defaultStyle;

  ProjectProgress get progress {
  return ProjectProgress(tasks);
  }

  ProjectStatistics get statistics {
  return ProjectStatistics(this);
  }

  ProjectSummary get summary {
  return ProjectSummary(this);
   }

  //==========================================
  void updateImageFromJob(Job job) {
    GeneratedImage? image;
    for (final candidate in images) {
      if (candidate.jobId == job.id) {
        image = candidate;
        break;
      }
    }

    if (image == null) {
      return;
    }
    
    image.asset = Asset(
      id: job.id,
      path: job.result ?? "",
      type: AssetType.image,
    );
  }

  //==========================================
  void updateAudioFromJob(Job job) {
    GeneratedAudio? audio;
    for (final candidate in audios) {
      if (candidate.jobId == job.id) {
        audio = candidate;
        break;
      }
    }

    if (audio == null) {
      return;
    }
    
    audio.asset = Asset(
      id: job.id,
      path: job.result ?? "",
      type: AssetType.audio,
    );
  }

 //============================================
 Map<String, dynamic> toJson() {
  return {
    "id": id,
    "idea": idea,
    "story": story.toJson(),
    "stage": stage.name,
    "images": images.map((e) => e.toJson()).toList(),
    "audios": audios.map((e) => e.toJson()).toList(),
    "finalVideoPath": finalVideoPath,
    "characters": characters.map((e) => e.toJson()).toList(),
    "tasks": tasks.map((e) => e.toJson()).toList(),
    "jobs": jobs.map((e) => e.toJson()).toList(),
    "settings": settings,
    "metadata": metadata,
    "style": style.toJson(),
  };
 }
 //======================================
  factory NoemaProject.fromJson(
  Map<String, dynamic> json,
) {
  final project = NoemaProject(
    id: json["id"] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    idea: json["idea"],
    story: Story.fromJson(
      json["story"],
    ),
  );

  project.stage = ProjectStage.values.byName(
    json["stage"],
  );

  project.images.addAll(
    (json["images"] as List)
        .map(
          (e) => GeneratedImage.fromJson(e),
        ),
  );

  if (json["audios"] != null) {
    project.audios.addAll(
      (json["audios"] as List)
          .map(
            (e) => GeneratedAudio.fromJson(e),
          ),
    );
  }

  project.finalVideoPath = json["finalVideoPath"];

  project.characters.addAll(
    (json["characters"] as List)
        .map(
          (e) => Character.fromJson(e),
        ),
  );

  project.tasks.addAll(
    (json["tasks"] as List)
        .map(
          (e) => ProjectTask.fromJson(e),
        ),
  );

  project.jobs.addAll(
    (json["jobs"] as List)
        .map(
          (e) => Job.fromJson(e),
        ),
  );

  project.settings.addAll(
    Map<String, dynamic>.from(
      json["settings"],
    ),
  );

  project.metadata.addAll(
    Map<String, dynamic>.from(
      json["metadata"],
    ),
  );

  project.style = Style.fromJson(
    json["style"],
  );

  return project;
}
}