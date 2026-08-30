import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/noema_exception.dart';

class PreflightCheckResult {
  final bool isOk;
  final String? missingNode;
  final String? missingModel;
  final String? inputName;
  final String? message;

  const PreflightCheckResult.success()
    : isOk = true,
      missingNode = null,
      missingModel = null,
      inputName = null,
      message = null;

  const PreflightCheckResult.missingNode(String nodeClass)
    : isOk = false,
      missingNode = nodeClass,
      missingModel = null,
      inputName = null,
      message = "Missing node type in ComfyUI: '$nodeClass'";

  const PreflightCheckResult.missingModel({
    required String nodeClass,
    required String input,
    required String model,
  }) : isOk = false,
       missingNode = null,
       missingModel = model,
       inputName = input,
       message =
           "Model '$model' for input '$input' in node '$nodeClass' is not installed on ComfyUI server";
}

class ComfyUIPreflightChecker {
  final String baseUrl;
  Map<String, dynamic>? _objectInfoCache;
  DateTime? _lastFetch;

  ComfyUIPreflightChecker({required this.baseUrl});

  /// Fetches `/object_info` from ComfyUI server. Caches for 1 minute.
  Future<Map<String, dynamic>> fetchObjectInfo({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _objectInfoCache != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 1) {
      return _objectInfoCache!;
    }

    try {
      final response = await http
          .get(Uri.parse("$baseUrl/object_info"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _objectInfoCache = jsonDecode(response.body) as Map<String, dynamic>;
        _lastFetch = DateTime.now();
        return _objectInfoCache!;
      } else {
        throw NoemaException.fromType(
          NoemaErrorType.networkError,
          "Failed to fetch ComfyUI object info (HTTP ${response.statusCode})",
        );
      }
    } catch (e) {
      if (e is NoemaException) rethrow;
      throw NoemaException.fromType(
        NoemaErrorType.networkError,
        "Cannot connect to ComfyUI server at $baseUrl to perform pre-flight check: $e",
      );
    }
  }

  /// Checks if a specific node class exists in ComfyUI object_info schema
  Future<bool> isNodeInstalled(String nodeClass) async {
    final info = await fetchObjectInfo();
    return info.containsKey(nodeClass);
  }

  /// Validates a full API prompt (workflow JSON map) against installed nodes & models.
  Future<PreflightCheckResult> validateWorkflow(
    Map<String, dynamic> promptJson, {
    bool isRetry = false,
  }) async {
    final objectInfo = await fetchObjectInfo(forceRefresh: isRetry);

    for (final entry in promptJson.entries) {
      final nodeData = entry.value;
      if (nodeData is! Map<String, dynamic>) continue;

      final classType = nodeData['class_type'] as String?;
      if (classType == null) continue;

      // 1. Check if class_type exists on server
      if (!objectInfo.containsKey(classType)) {
        if (!isRetry) {
          // Self-healing: force refresh cache in case node was just installed
          return validateWorkflow(promptJson, isRetry: true);
        }
        return PreflightCheckResult.missingNode(classType);
      }

      final classSchema = objectInfo[classType] as Map<String, dynamic>?;
      if (classSchema == null) continue;

      final inputsSchema = classSchema['input'] as Map<String, dynamic>?;
      final requiredInputs = inputsSchema?['required'] as Map<String, dynamic>?;

      if (requiredInputs == null) continue;

      // 2. Check inputs (like ckpt_name, lora_name, ipadapter_file) if present in prompt
      final nodeInputs = nodeData['inputs'] as Map<String, dynamic>?;
      if (nodeInputs == null) continue;

      for (final inputEntry in nodeInputs.entries) {
        final paramName = inputEntry.key;
        final paramValue = inputEntry.value;

        if (paramValue is! String) {
          continue; // Only check string values (filenames)
        }

        if (requiredInputs.containsKey(paramName)) {
          final paramSpec = requiredInputs[paramName];
          // ComfyUI object_info format: [ ["model1.safetensors", "model2.safetensors"], { ... } ]
          if (paramSpec is List &&
              paramSpec.isNotEmpty &&
              paramSpec[0] is List) {
            final availableModels = (paramSpec[0] as List).cast<String>();
            // If models list is non-empty and does not contain requested file
            if (availableModels.isNotEmpty &&
                !availableModels.contains(paramValue)) {
              if (!isRetry) {
                // Self-healing: force refresh cache in case model file was just placed on server
                return validateWorkflow(promptJson, isRetry: true);
              }
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
