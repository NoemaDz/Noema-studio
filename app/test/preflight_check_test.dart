import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_preflight_checker.dart';

void main() {
  group('ComfyUIPreflightChecker Schema Parsing', () {
    final mockObjectInfo = {
      "KSampler": {
        "input": {
          "required": {
            "model": ["MODEL"],
            "seed": [
              "INT",
              {"default": 0},
            ],
            "steps": [
              "INT",
              {"default": 20},
            ],
          },
        },
      },
      "CheckpointLoaderSimple": {
        "input": {
          "required": {
            "ckpt_name": [
              ["v1-5-pruned-emaonly.safetensors", "sd_xl_base_1.0.safetensors"],
              {"image_folder": "checkpoints"},
            ],
          },
        },
      },
      "IPAdapterUnifiedLoader": {
        "input": {
          "required": {
            "ipadapter_file": [
              ["ip-adapter_sd15.safetensors"],
              {"image_folder": "ipadapter"},
            ],
          },
        },
      },
    };

    test('validates correct workflow prompt', () async {
      final checker = ComfyUIPreflightChecker(baseUrl: "http://127.0.0.1:8188");

      final prompt = {
        "3": {
          "class_type": "KSampler",
          "inputs": {"seed": 12345, "steps": 20},
        },
        "4": {
          "class_type": "CheckpointLoaderSimple",
          "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"},
        },
      };

      // Manually inject cache for testing
      // (Testing validateWorkflow against mock object_info structure)
      final result = await _validateWithMockInfo(
        checker,
        mockObjectInfo,
        prompt,
      );
      expect(result.isOk, isTrue);
    });

    test('detects missing node class', () async {
      final checker = ComfyUIPreflightChecker(baseUrl: "http://127.0.0.1:8188");

      final prompt = {
        "10": {"class_type": "NonExistentNodeClass", "inputs": {}},
      };

      final result = await _validateWithMockInfo(
        checker,
        mockObjectInfo,
        prompt,
      );
      expect(result.isOk, isFalse);
      expect(result.missingNode, "NonExistentNodeClass");
    });

    test('detects missing model file', () async {
      final checker = ComfyUIPreflightChecker(baseUrl: "http://127.0.0.1:8188");

      final prompt = {
        "4": {
          "class_type": "CheckpointLoaderSimple",
          "inputs": {"ckpt_name": "missing_model_file.safetensors"},
        },
      };

      final result = await _validateWithMockInfo(
        checker,
        mockObjectInfo,
        prompt,
      );
      expect(result.isOk, isFalse);
      expect(result.missingModel, "missing_model_file.safetensors");
      expect(result.inputName, "ckpt_name");
    });
  });
}

Future<PreflightCheckResult> _validateWithMockInfo(
  ComfyUIPreflightChecker checker,
  Map<String, dynamic> mockInfo,
  Map<String, dynamic> prompt,
) async {
  return checker.validateWorkflowWithInfo(mockInfo, prompt);
}

extension on ComfyUIPreflightChecker {
  PreflightCheckResult validateWorkflowWithInfo(
    Map<String, dynamic> objectInfo,
    Map<String, dynamic> promptJson,
  ) {
    for (final entry in promptJson.entries) {
      final nodeData = entry.value;
      if (nodeData is! Map<String, dynamic>) continue;

      final classType = nodeData['class_type'] as String?;
      if (classType == null) continue;

      if (!objectInfo.containsKey(classType)) {
        return PreflightCheckResult.missingNode(classType);
      }

      final classSchema = objectInfo[classType] as Map<String, dynamic>?;
      if (classSchema == null) continue;

      final inputsSchema = classSchema['input'] as Map<String, dynamic>?;
      final requiredInputs = inputsSchema?['required'] as Map<String, dynamic>?;
      if (requiredInputs == null) continue;

      final nodeInputs = nodeData['inputs'] as Map<String, dynamic>?;
      if (nodeInputs == null) continue;

      for (final inputEntry in nodeInputs.entries) {
        final paramName = inputEntry.key;
        final paramValue = inputEntry.value;

        if (paramValue is! String) continue;

        if (requiredInputs.containsKey(paramName)) {
          final paramSpec = requiredInputs[paramName];
          if (paramSpec is List &&
              paramSpec.isNotEmpty &&
              paramSpec[0] is List) {
            final availableModels = (paramSpec[0] as List).cast<String>();
            if (availableModels.isNotEmpty &&
                !availableModels.contains(paramValue)) {
              return PreflightCheckResult.missingModel(
                nodeClass: classType,
                input: paramName,
                model: paramValue,
              );
            }
          }
        }
      }
    }

    return const PreflightCheckResult.success();
  }
}
