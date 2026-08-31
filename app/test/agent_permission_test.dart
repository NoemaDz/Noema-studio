import 'package:flutter_test/flutter_test.dart';
import 'package:noema_studio/agent/permissions/permission_policy.dart';
import 'package:noema_studio/agent/permissions/agent_permission.dart';
import 'package:noema_studio/agent/permissions/permission_scope.dart';
import 'package:noema_studio/agent/permissions/tool_risk_level.dart';

void main() {
  group('PermissionPolicy', () {
    test('safe tools are always authorized', () {
      final policy = PermissionPolicy();
      expect(policy.isAuthorized('read_project', ToolRiskLevel.safe), isTrue);
    });

    test('high risk tools require explicit permission', () {
      final policy = PermissionPolicy();
      expect(
        policy.isAuthorized('delete_project', ToolRiskLevel.high),
        isFalse,
      );
    });

    test('granted permission allows execution', () {
      final policy = PermissionPolicy();
      policy.grant(
        AgentPermission(
          toolId: 'generate_image',
          scope: PermissionScope.session,
          grantedAt: DateTime.now(),
        ),
      );
      expect(policy.isAuthorized('generate_image', ToolRiskLevel.high), isTrue);
    });

    test('expired permissions are rejected', () {
      final policy = PermissionPolicy();
      policy.grant(
        AgentPermission(
          toolId: 'generate_image',
          scope: PermissionScope.session,
          grantedAt: DateTime.now().subtract(const Duration(hours: 2)),
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      expect(
        policy.isAuthorized('generate_image', ToolRiskLevel.high),
        isFalse,
      );
    });

    test('once scope permissions are removed after execution', () {
      final policy = PermissionPolicy();
      policy.grant(
        AgentPermission(
          toolId: 'create_scene',
          scope: PermissionScope.once,
          grantedAt: DateTime.now(),
        ),
      );
      expect(
        policy.isAuthorized('create_scene', ToolRiskLevel.moderate),
        isTrue,
      );

      policy.onActionComplete('create_scene');

      expect(
        policy.isAuthorized('create_scene', ToolRiskLevel.moderate),
        isFalse,
      );
    });
  });
}
