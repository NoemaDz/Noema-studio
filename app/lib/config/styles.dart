import '../models/style.dart';

class Styles {
  static const pixar = Style(
    name: "Pixar",

    positivePrompt:
        "Pixar style, masterpiece, best quality, cinematic lighting, vibrant colors, highly detailed",

    negativePrompt:
        "low quality, blurry, watermark, text, logo, extra fingers, bad anatomy",

    width: 1024,

    height: 1024,

    steps: 20,

    cfg: 7,

    sampler: "euler",

    scheduler: "normal",
  );
}
