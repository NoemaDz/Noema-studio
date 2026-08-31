import '../core/noema.dart';
import 'models/agent_action.dart';
import 'permissions/permission_policy.dart';

abstract class AgentToolbox {
  Future<dynamic> executeAction(AgentAction action);
}

class NoemaAgentToolbox implements AgentToolbox {
  final Noema noema;
  final PermissionPolicy permissionPolicy;

  NoemaAgentToolbox({required this.noema, required this.permissionPolicy});

  @override
  Future<dynamic> executeAction(AgentAction action) async {
    if (!permissionPolicy.isAuthorized(action.toolId, action.riskLevel)) {
      throw Exception('Unauthorized action: ${action.toolId}');
    }

    // A real implementation would map toolIds to specific Noema calls
    switch (action.toolId) {
      case 'create_scene':
        // Example: interact with projectGenerationService or similar
        return {'status': 'success', 'sceneId': 'scene_123'};
      case 'generate_image':
        final prompt = action.arguments['prompt'] as String;
        final job = await noema.generateImage(prompt);
        return {'status': 'success', 'jobId': job.id};
      default:
        throw UnimplementedError(
          'Tool ${action.toolId} is not implemented yet.',
        );
    }
  }
}
