

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
  bool setInputByClass(String classType, String inputKey, dynamic value, {bool firstOnly = true}) {
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
    if (workflow.containsKey('3') && workflow['3']['class_type'] == 'CLIPTextEncode') {
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
      final uri = Uri.parse(fullPath);
      final filename = uri.queryParameters['filename'] ?? 'image.png';

      // 1. Try semantic title: "Character Image 1", "Character Image 2" etc.
      if (setInputByTitle('Character Image ${i + 1}', 'image', filename)) {
        continue;
      }

      // 2. Backward compatibility: nodes starting at ID 100+i
      final legacyId = (100 + i).toString();
      if (workflow.containsKey(legacyId) && workflow[legacyId]['class_type'] == 'LoadImage') {
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
        if (node is Map<String, dynamic> && node['class_type'] == 'EmptyLatentImage') {
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

  Map<String, dynamic> toJson() => workflow;
}
