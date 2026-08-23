import '../../core/providers/image_provider.dart';
import '../../core/workflow/workflow.dart';

import 'generate_image_step.dart';

class ImageWorkflow extends Workflow {
  ImageWorkflow(ImageProvider provider)
      : super(
          id: "image_workflow",
          name: "Image Workflow",
          steps: [
            GenerateImageStep(provider),
          ],
        );
}