class AgentToolSchema {
  final String id;
  final String description;
  final Map<String, dynamic> parameters;

  AgentToolSchema({
    required this.id,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'parameters': parameters,
  };
}
