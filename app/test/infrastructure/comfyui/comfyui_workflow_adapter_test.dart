import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_workflow_adapter.dart';

void main() {
  group('ComfyUIWorkflowAdapter', () {
    test(
      'setPrompt correctly updates semantic node and class_type fallback',
      () {
        final json = {
          "1": {
            "class_type": "OtherNode",
            "inputs": {"text": "ignore me"},
          },
          "2": {
            "class_type": "CLIPTextEncode",
            "_meta": {"title": "Positive Prompt"},
            "inputs": {"text": "old prompt"},
          },
        };

        final adapter = ComfyUIWorkflowAdapter(json);
        adapter.setPrompt("new prompt");

        expect((json["2"] as Map)["inputs"]["text"], "new prompt");
        expect((json["1"] as Map)["inputs"]["text"], "ignore me");
      },
    );

    test('applyOptions sets width and height on EmptyLatentImage', () {
      final json = {
        "10": {
          "class_type": "EmptyLatentImage",
          "inputs": {"width": 512, "height": 512, "batch_size": 1},
        },
      };

      final adapter = ComfyUIWorkflowAdapter(json);
      adapter.applyOptions({"width": 1024, "height": 1024});

      expect((json["10"] as Map)["inputs"]["width"], 1024);
      expect((json["10"] as Map)["inputs"]["height"], 1024);
    });
  });
}
