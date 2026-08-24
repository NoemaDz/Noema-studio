import '../../core/workflow/workflow.dart';
import '../../core/workflow/workflow_step.dart';

class ProjectWorkflow extends Workflow {
  ProjectWorkflow(List<WorkflowStep> steps)
    : super(id: "project", name: "Project Workflow", steps: steps);
}
