enum GenerationState {
  draft,
  planning,
  reviewing,
  generating,
  completed,
  failed,
  stopped,
}

extension GenerationStateExtension on GenerationState {
  String toJson() => name;

  static GenerationState fromJson(String? value) {
    if (value == null) return GenerationState.draft;
    return GenerationState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GenerationState.draft,
    );
  }
}
