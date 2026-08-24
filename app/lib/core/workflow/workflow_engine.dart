import 'workflow.dart';
import 'workflow_context.dart';

class WorkflowEngine {
  Future<WorkflowContext> run(Workflow workflow) async {
    final context = WorkflowContext();

    for (final step in workflow.steps) {
      final result = await step.execute(context);
      context.set(step.id, result);
    }

    return context;
  }

  Future<WorkflowContext> runWithContext(
    Workflow workflow,
    WorkflowContext context,
  ) async {
    for (final step in workflow.steps) {
      final result = await step.execute(context);
      context.set(step.id, result);
    }

    return context;
  }
}
