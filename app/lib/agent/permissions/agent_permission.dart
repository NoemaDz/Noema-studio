import 'permission_scope.dart';

class AgentPermission {
  final String toolId;
  final PermissionScope scope;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> constraints;

  AgentPermission({
    required this.toolId,
    required this.scope,
    required this.grantedAt,
    this.expiresAt,
    this.constraints = const {},
  });
}
