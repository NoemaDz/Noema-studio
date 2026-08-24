import '../../models/style.dart';

class StyleRegistry {
  static const Style cinematic = Style(
    name: "Cinematic",

    positivePrompt:
        "cinematic lighting, masterpiece, ultra detailed, 8k, highly detailed, dramatic composition",

    negativePrompt:
        "low quality, blurry, bad anatomy, extra fingers, watermark, text",

    width: 1024,
    height: 1024,

    steps: 30,

    cfg: 7.5,

    sampler: "dpmpp_2m",

    scheduler: "karras",
  );

  static const Style anime = Style(
    name: "Anime",

    positivePrompt: "anime, masterpiece, vibrant colors, highly detailed",

    negativePrompt: "low quality, blurry, watermark",

    width: 1024,
    height: 1024,

    steps: 28,

    cfg: 7,

    sampler: "dpmpp_2m",

    scheduler: "karras",
  );

  static Style get defaultStyle => cinematic;

  static List<Style> get all => [cinematic, anime];
}
