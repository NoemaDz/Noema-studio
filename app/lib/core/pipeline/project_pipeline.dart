import '../noema_project.dart';




import 'pipeline_registry.dart';






class ProjectPipeline {
  
  final PipelineRegistry registry;

  ProjectPipeline({
  required this.registry,
  });

    Future<NoemaProject> generate(NoemaProject project) async {
    // We already have the project, just run the stages
    for (final stage in registry.stages) {
  await stage.run(project);
 }

  return project;
 }
 
}