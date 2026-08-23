class Style {
  final String name;

  final String positivePrompt;
  final String negativePrompt;

  final int width;
  final int height;

  final int steps;
  final double cfg;

  final String sampler;
  final String scheduler;

  const Style({
    required this.name,
    required this.positivePrompt,
    required this.negativePrompt,
    required this.width,
    required this.height,
    required this.steps,
    required this.cfg,
    required this.sampler,
    required this.scheduler,
  });


  factory Style.fromJson(
  Map<String, dynamic> json,
 ) {
  return Style(
    name: json["name"],
    positivePrompt: json["positivePrompt"],
    negativePrompt: json["negativePrompt"],
    width: json["width"],
    height: json["height"],
    steps: json["steps"],
    cfg: (json["cfg"] as num).toDouble(),
    sampler: json["sampler"],
    scheduler: json["scheduler"],
  );
 }

 Map<String, dynamic> toJson() {
  return {
    "name": name,
    "positivePrompt": positivePrompt,
    "negativePrompt": negativePrompt,
    "width": width,
    "height": height,
    "steps": steps,
    "cfg": cfg,
    "sampler": sampler,
    "scheduler": scheduler,
  };
 }
}