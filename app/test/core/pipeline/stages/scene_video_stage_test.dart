import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/pipeline/stages/scene_video_stage.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/models/scene.dart';
import 'package:noema_studio/core/settings/app_settings.dart';
import 'package:noema_studio/core/providers/video_provider.dart';
import 'package:noema_studio/core/job_manager.dart';
import 'package:noema_studio/core/workflow/workflow_engine.dart';
import 'package:noema_studio/core/capabilities/capability.dart';
import 'package:noema_studio/models/generated_video.dart';
import 'package:noema_studio/models/generated_image.dart';
import 'package:noema_studio/models/artifact.dart';
import 'package:noema_studio/models/artifact_type.dart';
import 'package:noema_studio/models/job.dart';

class MockCloudVideoProvider extends VideoProvider {
  @override
  String get id => "gemini_video";

  @override
  String get name => "Mock Cloud Video";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalVideoProvider extends VideoProvider {
  @override
  String get id => "comfyui_video";

  @override
  String get name => "Mock Local Video";

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {CapabilityType.videoGeneration};

  @override
  HardwareRequirements get hardwareRequirements =>
      const HardwareRequirements(requiresGPU: true, minimumVRAMGB: 8);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAppSettings implements AppSettings {
  @override
  bool get enableVideoGeneration => true;
  @override
  String get geminiVideoModel => 'mock-model';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWorkflowEngine implements WorkflowEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockJobManager implements JobManager {
  @override
  Job? find(String id) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Test A - Cloud provider does not require local GPU', () {
    final cloudProvider = MockCloudVideoProvider();
    final stage1 = SceneVideoStage(
      engine: MockWorkflowEngine(),
      provider: cloudProvider,
      jobManager: MockJobManager(),
      appSettings: MockAppSettings(),
    );
    expect(stage1.requiresGPU, false);

    final localProvider = MockLocalVideoProvider();
    final stage2 = SceneVideoStage(
      engine: MockWorkflowEngine(),
      provider: localProvider,
      jobManager: MockJobManager(),
      appSettings: MockAppSettings(),
    );
    expect(stage2.requiresGPU, true);
  });

  test('Test B - Missing Job invalidates video cache', () async {
    final provider = MockCloudVideoProvider();
    final stage = SceneVideoStage(
      engine: MockWorkflowEngine(),
      provider: provider,
      jobManager: MockJobManager(),
      appSettings: MockAppSettings(),
    );

    // Setup a dummy file that exists
    final tempDir = await Directory.systemTemp.createTemp('video_stage_test_');
    final dummyVideoFile = File('${tempDir.path}/dummy_video.mp4');
    await dummyVideoFile.writeAsBytes([0, 0, 0]);

    final dummyImageFile = File('${tempDir.path}/dummy_image.jpg');
    await dummyImageFile.writeAsBytes([0, 0, 0]);

    final project = NoemaProject(
      id: "proj-1",
      idea: "Test Idea",
      story: Story(
        title: "Story",
        scenes: [Scene(id: 1, description: "A bird", imagePrompt: "A bird")],
      ),
    );

    // Valid generated image
    project.images.add(
      GeneratedImage(
        sceneId: 1,
        jobId: "img-job-1",
        prompt: "A bird",
        artifact: Artifact(
          id: "art-1",
          path: dummyImageFile.path,
          type: ArtifactType.image,
        ),
      ),
    );

    // Existing video BUT no associated Job in project.savedJobs or JobManager
    project.videos.add(
      GeneratedVideo(
        sceneId: 1,
        jobId: "missing-job",
        sourceImagePath: dummyImageFile.path,
        artifact: Artifact(
          id: "art-2",
          path: dummyVideoFile.path,
          type: ArtifactType.video,
        ),
      ),
    );

    // Because the Job is missing, cache should be invalidated, and it should proceed to try and generate.
    // Since MockWorkflowEngine throws NoSuchMethodError when runWithContext is called,
    // catching that error means cache validation failed and it attempted to run the workflow.

    bool attemptedToRun = false;
    try {
      await stage.runForScene(project, project.story.scenes.first);
    } on NoSuchMethodError catch (_) {
      attemptedToRun = true;
    }

    expect(attemptedToRun, true);

    await tempDir.delete(recursive: true);
  });
}
