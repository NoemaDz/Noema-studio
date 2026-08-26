import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/infrastructure/comfyui/comfyui_workflow_adapter.dart';
import 'package:noema_studio/core/hardware/hardware_service.dart';

dynamic getInputByClass(Map<String, dynamic> workflow, String className, String inputName) {
  for (final node in workflow.values) {
    if (node is Map<String, dynamic> && node['class_type'] == className) {
      if (node['inputs'] != null && node['inputs'].containsKey(inputName)) {
        return node['inputs'][inputName];
      }
    }
  }
  return null;
}

void main() {
  test('I2V Workflow correctly applies VRAM safeguards (14 frames)', () async {
    final file = File('assets/workflows/image_to_video_api.json');
    final jsonStr = await file.readAsString();
    final Map<String, dynamic> workflow = jsonDecode(jsonStr);
    
    final adapter = ComfyUIWorkflowAdapter(workflow);
    
    // Apply Balanced profile (should reduce to 14 frames)
    adapter.applyPerformanceProfile(PerformanceProfile.balanced);
    
    // Check if frames were reduced
    final frames = getInputByClass(workflow, 'SVD_img2vid_Conditioning', 'video_frames');
    expect(frames, 14, reason: "SVD video_frames should be reduced to 14 to save VRAM on balanced profile.");
    
    // Test custom options
    adapter.applyOptions({'motion': 200, 'augmentation': 0.1});
    final motion = getInputByClass(workflow, 'SVD_img2vid_Conditioning', 'motion_bucket_id');
    final aug = getInputByClass(workflow, 'SVD_img2vid_Conditioning', 'augmentation_level');
    
    expect(motion, 200, reason: "Motion should be configurable.");
    expect(aug, 0.1, reason: "Augmentation should be configurable.");
  });
}
