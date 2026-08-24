import '../../providers/llm_provider.dart';
import '../../workflow/workflow_context.dart';
import '../../workflow/workflow_engine.dart';
import 'dart:convert';

import '../../../models/story.dart';
import '../../noema_project.dart';

import '../../../workflows/story/story_workflow.dart';
import '../contracts/pipeline_stage.dart';

class StoryStage extends PipelineStage {
  @override
  int get priority => 10;

  final WorkflowEngine engine;

  final LLMProvider provider;

  StoryStage({required this.engine, required this.provider});

  @override
  Future<void> run(NoemaProject project) async {
    final workflow = StoryWorkflow(provider);

    final context = WorkflowContext();

    context.set("idea", project.idea);

    final result = await engine.runWithContext(workflow, context);
    final storyText = result.get<String>("story")!;

    project.story = Story.fromJson(jsonDecode(storyText));
  }
}
