import 'workflow.dart';
import 'workflow_context.dart';
import '../cancellation_token.dart';

class WorkflowEngine {
  Future<WorkflowContext> run(
    Workflow workflow, {
    CancellationToken? cancellationToken,
  }) async {
    final context = WorkflowContext();

    for (final step in workflow.steps) {
      cancellationToken?.throwIfCancelled();
      final result = await step.execute(context);
      context.set(step.id, result);
    }

    return context;
  }

  Future<WorkflowContext> runWithContext(
    Workflow workflow,
    WorkflowContext context, {
    CancellationToken? cancellationToken,
  }) async {
    for (final step in workflow.steps) {
      cancellationToken?.throwIfCancelled();
      final result = await step.execute(context);
      context.set(step.id, result);
    }

    return context;
  }
}
