import '../core/noema.dart';
import '../core/noema_project.dart';
import 'models/agent_action.dart';
import 'models/agent_tool_schema.dart';
import 'permissions/permission_policy.dart';

import 'models/agent_session.dart';
import 'permissions/tool_risk_level.dart';

class UnauthorizedException implements Exception {
  final String toolId;
  UnauthorizedException(this.toolId);
  @override
  String toString() => 'Unauthorized action: $toolId';
}

abstract class AgentToolbox {
  Future<dynamic> executeAction(AgentSession session, AgentAction action);
  List<AgentToolSchema> getAvailableTools();
}

class NoemaAgentToolbox implements AgentToolbox {
  final Noema noema;
  final PermissionPolicy permissionPolicy;

  NoemaAgentToolbox({required this.noema, required this.permissionPolicy});

  @override
  Future<dynamic> executeAction(
    AgentSession session,
    AgentAction action,
  ) async {
    // Single Source of Truth for permission enforcement
    if (!permissionPolicy.isAuthorized(action.toolId, action.riskLevel)) {
      throw UnauthorizedException(action.toolId);
    }

    // Helper to get project safely
    NoemaProject getProject() {
      final projectId = action.arguments['projectId'] as String;
      if (projectId != session.currentProject.id) {
        throw Exception(
          'Project ID mismatch. Expected ${session.currentProject.id}',
        );
      }
      return session.currentProject;
    }

    // Map toolIds to specific Noema calls
    switch (action.toolId) {
      case 'generate_story':
        final idea = action.arguments['idea'] as String;
        final result = await noema.generateStory(idea);
        return {'status': 'success', 'story': result};

      case 'generate_planning':
        final project = getProject();
        final result = await noema.generatePlanning(project);
        return {'status': 'success', 'projectId': result.id};

      case 'extract_characters':
        final project = getProject();
        await noema.extractCharacters(project);
        return {'status': 'success'};

      case 'generate_production':
        final project = getProject();
        final result = await noema.generateProduction(project);
        return {'status': 'success', 'projectId': result.id};

      case 'generate_image':
        final prompt = action.arguments['prompt'] as String;
        final job = await noema.generateImage(prompt);
        return {'status': 'success', 'jobId': job.id};

      case 'save_project':
        final project = getProject();
        await noema.saveProject(project);
        return {'status': 'success'};

      default:
        throw UnimplementedError(
          'Tool ${action.toolId} is not implemented yet.',
        );
    }
  }

  @override
  List<AgentToolSchema> getAvailableTools() {
    return [
      AgentToolSchema(
        id: 'generate_story',
        description: 'Generates a multi-scene story from a simple idea.',
        parameters: {'idea': 'string'},
        riskLevel: ToolRiskLevel.moderate,
      ),
      AgentToolSchema(
        id: 'generate_planning',
        description: 'Generates a production plan (tasks) for the project.',
        parameters: {'projectId': 'string'},
        riskLevel: ToolRiskLevel.high,
      ),
      AgentToolSchema(
        id: 'extract_characters',
        description: 'Extracts consistent character profiles from the story.',
        parameters: {'projectId': 'string'},
        riskLevel: ToolRiskLevel.moderate,
      ),
      AgentToolSchema(
        id: 'generate_production',
        description: 'Compiles all generated assets into a final video.',
        parameters: {'projectId': 'string'},
        riskLevel: ToolRiskLevel.high,
      ),
      AgentToolSchema(
        id: 'generate_image',
        description: 'Generates an image from a prompt.',
        parameters: {'prompt': 'string'},
        riskLevel: ToolRiskLevel.high,
      ),
      AgentToolSchema(
        id: 'save_project',
        description: 'Saves the project state to disk.',
        parameters: {'projectId': 'string'},
        riskLevel: ToolRiskLevel.safe,
      ),
    ];
  }
}
