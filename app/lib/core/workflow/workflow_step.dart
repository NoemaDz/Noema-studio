

import 'workflow_context.dart';

abstract class WorkflowStep<T> {
  String get id;
  String get name;

  Future<T> execute(WorkflowContext context);
}