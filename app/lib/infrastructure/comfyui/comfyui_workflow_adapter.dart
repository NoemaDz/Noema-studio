import 'package:path/path.dart' as p;
import 'package:noema_studio/core/hardware/hardware_service.dart';

class ComfyUIWorkflowAdapter {
  final Map<String, dynamic> workflow;

  ComfyUIWorkflowAdapter(this.workflow);

  /// Helper to set an input value for a node matching a specific `_meta.title`.
  bool setInputByTitle(String title, String inputKey, dynamic value) {
    bool found = false;
    for (final node in workflow.values) {
      if (node is Map<String, dynamic> &&
          node['_meta'] != null &&
          node['_meta']['title'] == title) {
        if (node['inputs'] != null) {
          node['inputs'][inputKey] = value;
          found = true;
        }
      }
    }
    return found;
  }

  /// Helper to set an input value for a node matching a specific `class_type`.
  /// Updates all matching nodes unless `firstOnly` is true.
  bool setInputByClass(
    String classType,
    String inputKey,
    dynamic value, {
    bool firstOnly = true,
  }) {
    bool found = false;
    for (final node in workflow.values) {
      if (node is Map<String, dynamic> && node['class_type'] == classType) {
        if (node['inputs'] != null) {
          node['inputs'][inputKey] = value;
          found = true;
          if (firstOnly) return true;
        }
      }
    }
    return found;
  }

  /// Set the main positive prompt.
  void setPrompt(String prompt) {
    // 1. Try semantic title first
    if (setInputByTitle('Positive Prompt', 'text', prompt)) return;

    // 2. Backward compatibility for older text_to_image_api.json
    if (workflow.containsKey('3') &&
        workflow['3']['class_type'] == 'CLIPTextEncode') {
      workflow['3']['inputs']['text'] = prompt;
      return;
    }

    // 3. Fallback to the first CLIPTextEncode
    setInputByClass('CLIPTextEncode', 'text', prompt, firstOnly: true);
  }

  /// Set character images for IP-Adapter
  void setCharacterImages(List<dynamic> characters) {
    for (int i = 0; i < characters.length; i++) {
      final charData = characters[i] as Map<String, dynamic>;
      final fullPath = charData['imagePath'] as String;
      String filename = fullPath;
      try {
        final uri = Uri.parse(fullPath);
        if (uri.queryParameters.containsKey('filename')) {
          filename = uri.queryParameters['filename']!;
        } else {
          // If it's a local path or raw filename
          filename = p.basename(fullPath);
        }
      } catch (_) {}

      // 1. Try semantic title: "Character Image 1", "Character Image 2" etc.
      if (setInputByTitle('Character Image ${i + 1}', 'image', filename)) {
        continue;
      }

      // 2. Backward compatibility: nodes starting at ID 100+i
      final legacyId = (100 + i).toString();
      if (workflow.containsKey(legacyId) &&
          workflow[legacyId]['class_type'] == 'LoadImage') {
        workflow[legacyId]['inputs']['image'] = filename;
      }
    }
  }

  /// Inject generic options (like seed, width, height) if present
  void applyOptions(Map<String, dynamic> options) {
    if (options.containsKey('seed')) {
      if (!setInputByTitle('KSampler', 'seed', options['seed'])) {
        setInputByClass('KSampler', 'seed', options['seed'], firstOnly: true);
      }
    }

    if (options.containsKey('width') || options.containsKey('height')) {
      // Find EmptyLatentImage
      for (final node in workflow.values) {
        if (node is Map<String, dynamic> &&
            node['class_type'] == 'EmptyLatentImage') {
          if (options.containsKey('width')) {
            node['inputs']['width'] = options['width'];
          }
          if (options.containsKey('height')) {
            node['inputs']['height'] = options['height'];
          }
          break; // Stop at first
        }
      }
    }
  }

  /// Set image resolution from a "WxH" string like "768x512"
  void setResolution(String resolution) {
    final parts = resolution.toLowerCase().split('x');
    if (parts.length != 2) return;
    final w = int.tryParse(parts[0].trim());
    final h = int.tryParse(parts[1].trim());
    if (w == null || h == null) return;

    for (final node in workflow.values) {
      if (node is Map<String, dynamic> &&
          node['class_type'] == 'EmptyLatentImage') {
        node['inputs']['width'] = w;
        node['inputs']['height'] = h;
        break;
      }
    }
  }

  /// Apply hardware-based performance profile
  void applyPerformanceProfile(PerformanceProfile profile) {
    if (profile == PerformanceProfile.ultra) {
      // Keep everything (FaceDetailer and PersonDetailer)
      return;
    }

    String? vaeDecodeNodeId;
    String? saveImageNodeId;
    String? faceDetailerNodeId;
    String? personDetailerNodeId;

    for (final entry in workflow.entries) {
      final node = entry.value;
      if (node is! Map<String, dynamic>) continue;

      final classType = node['class_type'] as String? ?? '';
      final title = (node['_meta'] as Map?)?['title'] as String? ?? '';

      if (classType == 'VAEDecode') vaeDecodeNodeId = entry.key;
      if (classType == 'SaveImage') saveImageNodeId = entry.key;

      if (classType == 'FaceDetailer') {
        if (title == 'PersonDetailer') {
          personDetailerNodeId = entry.key;
        } else {
          faceDetailerNodeId = entry.key;
        }
      }
    }

    if (profile == PerformanceProfile.fast) {
      // Remove both detailers, connect VAEDecode -> SaveImage
      if (saveImageNodeId != null && vaeDecodeNodeId != null) {
        workflow[saveImageNodeId]['inputs']['images'] = [vaeDecodeNodeId, 0];
      }
      _removeNodesByClass('FaceDetailer');
      _removeNodesByClass('UltralyticsDetectorProvider');
    } else if (profile == PerformanceProfile.balanced) {
      // Remove only PersonDetailer, connect FaceDetailer -> SaveImage
      if (saveImageNodeId != null && faceDetailerNodeId != null) {
        workflow[saveImageNodeId]['inputs']['images'] = [faceDetailerNodeId, 0];
      }
      if (personDetailerNodeId != null) {
        workflow.remove(personDetailerNodeId);
      }
      // Remove the Person detector (title == 'Person Detector (Segm)')
      final toRemove = <String>[];
      for (final entry in workflow.entries) {
        final node = entry.value;
        if (node is! Map<String, dynamic>) continue;
        if ((node['_meta'] as Map?)?['title'] == 'Person Detector (Segm)') {
          toRemove.add(entry.key);
        }
      }
      for (final key in toRemove) {
        workflow.remove(key);
      }
    }
  }

  void _removeNodesByClass(String classType) {
    final toRemove = <String>[];
    for (final entry in workflow.entries) {
      final node = entry.value;
      if (node is! Map<String, dynamic>) continue;
      if (node['class_type'] == classType) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      workflow.remove(key);
    }
  }

  Map<String, dynamic> toJson() => workflow;
}
