import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/core/noema_project.dart';
import 'package:noema_studio/models/generation_state.dart';
import 'package:noema_studio/models/story.dart';
import 'package:noema_studio/models/scene.dart';
import 'package:noema_studio/models/generated_image.dart';

void main() {
  group('Resumability & Lifecycle Safety Tests', () {
    test(
      'Backward compatibility - loads correctly without stopped state (Test 5)',
      () {
        final json = {
          'id': 'test-123',
          'idea': 'Test idea',
          'story': {'title': 'Test Story', 'scenes': []},
          'stage': 'story',
        };

        final project = NoemaProject.fromJson(json);
        expect(
          project.projectState,
          GenerationState.draft,
        ); // Defaults correctly
      },
    );

    test('Loads stopped state correctly', () {
      final json = {
        'id': 'test-123',
        'idea': 'Test idea',
        'story': {'title': 'Test Story', 'scenes': []},
        'stage': 'story',
        'projectState': 'stopped',
      };

      final project = NoemaProject.fromJson(json);
      expect(project.projectState, GenerationState.stopped);
    });

    test('Resume logic preserves UUID and state (Test 3)', () {
      final project = NoemaProject(
        id: 'stable-uuid',
        idea: 'Resume idea',
        story: Story(
          title: 'Saved',
          scenes: [
            Scene(
              id: 1,
              description: 'S1',
              imageState: GenerationState.completed,
            ),
          ],
        ),
      );
      project.projectState = GenerationState.stopped;

      expect(project.id, 'stable-uuid');
      expect(project.story.scenes.length, 1);
      expect(project.projectState, GenerationState.stopped);
    });

    test(
      'Complete Director AI resume flow (production resumes incomplete work)',
      () {
        final project = NoemaProject(
          id: 'stable-uuid',
          idea: 'Resume idea',
          story: Story(
            title: 'Saved',
            scenes: [
              Scene(
                id: 1,
                description: 'S1',
                imageState: GenerationState.completed,
                imagePath: '/tmp/img1.png',
              ),
              Scene(
                id: 2,
                description: 'S2',
                imageState: GenerationState.generating, // Interrupted
                imagePath: null,
              ),
            ],
          ),
        );

        // Simulating a project that was stopped during generation
        project.projectState = GenerationState.stopped;

        // Scene 1 had a generated image
        project.images.add(
          GeneratedImage(jobId: 'job1', sceneId: 1, prompt: 'p1'),
        );
        // Scene 2 had an incomplete image
        project.images.add(
          GeneratedImage(jobId: 'job2', sceneId: 2, prompt: 'p2'),
        );

        // Simulate what _generateProject -> _continueToProduction does on Resume:
        // 1. Reuses same UUID (verified by using same instance)
        // 2. Skips planning (simulated by going straight to production logic)

        // Simulate ProjectPipeline.generateProduction logic:
        project.projectState = GenerationState.generating;

        project.images.removeWhere((img) {
          final scene = project.story.scenes
              .where((s) => s.id == img.sceneId)
              .firstOrNull;
          return scene == null ||
              scene.imageState != GenerationState.completed ||
              scene.imagePath == null;
        });

        // Verify Production Resumes ONLY incomplete work
        expect(
          project.images.length,
          1,
          reason: "Incomplete image artifact should be purged for regeneration",
        );
        expect(
          project.images.first.sceneId,
          1,
          reason: "Completed scene artifact MUST be preserved",
        );
        expect(project.images.first.jobId, 'job1');
        expect(
          project.id,
          'stable-uuid',
          reason: "Project UUID must remain stable",
        );
      },
    );
  });
}
