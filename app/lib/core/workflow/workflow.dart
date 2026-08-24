import 'workflow_step.dart';

class Workflow {
  final String id;
  final String name;
  final List<WorkflowStep> steps;

  Workflow({required this.id, required this.name, required this.steps});
}
