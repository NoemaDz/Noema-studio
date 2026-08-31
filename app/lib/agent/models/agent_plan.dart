import 'agent_step.dart';

class AgentPlan {
  final String goal;
  final List<AgentStep> steps;

  AgentPlan({required this.goal, required this.steps});

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  factory AgentPlan.fromJson(Map<String, dynamic> json) {
    return AgentPlan(
      goal: json['goal'] as String,
      steps: (json['steps'] as List)
          .map((s) => AgentStep.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
