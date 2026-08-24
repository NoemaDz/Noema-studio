class ScenePrompt {
  final String positive;

  final String negative;

  final List<String> referenceImages;

  const ScenePrompt({
    required this.positive,
    required this.negative,
    this.referenceImages = const [],
  });
}
