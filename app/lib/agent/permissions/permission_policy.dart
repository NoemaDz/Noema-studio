import 'agent_permission.dart';
import 'permission_scope.dart';
import 'tool_risk_level.dart';

class PermissionPolicy {
  final List<AgentPermission> _grantedPermissions = [];

  void grant(AgentPermission permission) {
    _grantedPermissions.add(permission);
  }

  void revoke(String toolId) {
    _grantedPermissions.removeWhere((p) => p.toolId == toolId);
  }

  void revokeAll() {
    _grantedPermissions.clear();
  }

  void clearExpired() {
    final now = DateTime.now();
    _grantedPermissions.removeWhere(
      (p) => p.expiresAt != null && p.expiresAt!.isBefore(now),
    );
  }

  void onTaskComplete() {
    _grantedPermissions.removeWhere(
      (p) => p.scope == PermissionScope.task || p.scope == PermissionScope.once,
    );
  }

  void onActionComplete(String toolId) {
    // If a tool had a 'once' scope, it should be removed after execution.
    final oncePermissions = _grantedPermissions
        .where((p) => p.toolId == toolId && p.scope == PermissionScope.once)
        .toList();
    for (final p in oncePermissions) {
      _grantedPermissions.remove(p);
    }
  }

  bool isAuthorized(String toolId, ToolRiskLevel riskLevel) {
    clearExpired();

    if (riskLevel == ToolRiskLevel.safe) {
      return true;
    }

    final permission = _grantedPermissions
        .where((p) => p.toolId == toolId)
        .lastOrNull;

    if (permission == null) {
      return false;
    }

    if (permission.scope == PermissionScope.alwaysAsk) {
      return false;
    }

    return true;
  }
}
