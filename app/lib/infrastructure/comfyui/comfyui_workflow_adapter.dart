import 'package:path/path.dart' as p;
import 'package:noema_studio/core/hardware/hardware_service.dart';

class ComfyUIWorkflowAdapter {
  final Map<String, dynamic> workflow;
  final List<String> _characterPositions = ['center', 'center', 'center'];

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

  /// Helper to get an input value for a node matching a specific `_meta.title`.
  dynamic getInputByTitle(String title, String inputKey) {
    for (final node in workflow.values) {
      if (node is Map<String, dynamic> &&
          node['_meta'] != null &&
          node['_meta']['title'] == title) {
        if (node['inputs'] != null) {
          return node['inputs'][inputKey];
        }
      }
    }
    return null;
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
    // First, disable all multiple character IP-Adapters
    for (int i = 1; i <= 3; i++) {
      setInputByTitle('IPAdapter Advanced $i', 'weight', 0.0);
    }

    for (int i = 0; i < characters.length; i++) {
      if (i >= 3) break; // Max 3 characters

      final charData = characters[i] as Map<String, dynamic>;
      final fullPath = charData['imagePath'] as String;
      final position = charData['position'] as String? ?? 'center';

      _characterPositions[i] = position;

      String filename = fullPath;
      try {
        final uri = Uri.parse(fullPath);
        if (uri.queryParameters.containsKey('filename')) {
          filename = uri.queryParameters['filename']!;
        } else {
          filename = p.basename(fullPath);
        }
      } catch (_) {}

      // If this is the first character, set it as a fallback for all nodes to bypass ComfyUI missing file validation
      if (i == 0) {
        for (int j = 1; j <= 3; j++) {
          setInputByTitle('Character Image $j', 'image', filename);
        }
      }

      // Try semantic title: "Character Image 1", etc.
      if (setInputByTitle('Character Image ${i + 1}', 'image', filename)) {
        // Enable this IP-Adapter
        setInputByTitle('IPAdapter Advanced ${i + 1}', 'weight', 0.6);
        continue;
      }

      // Backward compatibility for single character
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

    if (options.containsKey('motion')) {
      setInputByClass(
        'SVD_img2vid_Conditioning',
        'motion_bucket_id',
        options['motion'],
        firstOnly: true,
      );
    }

    if (options.containsKey('augmentation')) {
      setInputByClass(
        'SVD_img2vid_Conditioning',
        'augmentation_level',
        options['augmentation'],
        firstOnly: true,
      );
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

    // Also update background mask for regional prompting
    setInputByTitle('Background Mask', 'width', w);
    setInputByTitle('Background Mask', 'height', h);

    // Determine number of active characters
    int activeCharacters = 0;
    for (int i = 1; i <= 3; i++) {
      final weight = getInputByTitle('IPAdapter Advanced $i', 'weight');
      if (weight != null && (weight as num) > 0.0) {
        activeCharacters++;
      }
    }

    // If no characters, default to 1 to avoid division by zero
    if (activeCharacters == 0) activeCharacters = 1;

    // Update region masks depending on position
    final regionWidth = w ~/ activeCharacters;

    for (int i = 0; i < 3; i++) {
      final pos = _characterPositions[i];
      int x = 0;

      if (activeCharacters == 1) {
        // Full screen mask for single character to prevent confining IPAdapter
        x = 0;
      } else if (pos == 'left') {
        x = 0;
      } else if (pos == 'center') {
        x = (w - regionWidth) ~/ 2;
      } else if (pos == 'right') {
        x = w - regionWidth;
      }

      setInputByTitle(
        'Region Mask ${i + 1}',
        'width',
        activeCharacters == 1 ? w : regionWidth,
      );
      setInputByTitle('Region Mask ${i + 1}', 'height', h);
      setInputByTitle('Composite Mask ${i + 1}', 'x', x);
    }
  }

  /// Apply hardware-based performance profile
  void applyPerformanceProfile(PerformanceProfile profile) {
    int activeCharacters = 0;
    for (int i = 1; i <= 3; i++) {
      final weight = getInputByTitle('IPAdapter Advanced $i', 'weight');
      if (weight != null && (weight as num) > 0.0) {
        activeCharacters++;
      }
    }

    if (activeCharacters > 1) {
      // For multiple characters, PLUS model takes too much VRAM. Downgrade to VIT-G.
      setInputByTitle(
        'IPAdapter Unified Loader',
        'preset',
        'VIT-G (medium strength)',
      );
      // Also downgrade Ultra to Balanced to remove PersonDetailer and save VRAM
      if (profile == PerformanceProfile.ultra) {
        profile = PerformanceProfile.balanced;
      }
    }

    if (profile == PerformanceProfile.ultra) {
      // Keep everything (FaceDetailer and PersonDetailer, and max video frames)
      return;
    }

    // --- I2V VRAM Safeguard ---
    // SVD needs a lot of VRAM for 24 frames. Downgrade to 14 frames if not ultra.
    setInputByClass(
      'SVD_img2vid_Conditioning',
      'video_frames',
      14,
      firstOnly: true,
    );

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
