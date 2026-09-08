import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';

final class BusinessContext {
  factory BusinessContext.verifiedMembership({
    required BusinessId businessId,
    required RemoteAuthUserId memberAuthUserId,
    required String role,
    required BusinessScope scope,
    BusinessId? warehouseMembershipBusinessId,
  }) {
    final normalizedRole = role.trim();
    if (normalizedRole != 'owner' && normalizedRole != 'employee') {
      throw ArgumentError.value(role, 'role');
    }
    if (scope is WarehouseScope &&
        warehouseMembershipBusinessId != businessId) {
      throw ArgumentError(
        'Warehouse scope requires membership evidence for the same business.',
      );
    }
    return BusinessContext._(
      businessId: businessId,
      memberAuthUserId: memberAuthUserId,
      role: normalizedRole,
      scope: scope,
    );
  }

  const BusinessContext._({
    required this.businessId,
    required this.memberAuthUserId,
    required this.role,
    required this.scope,
  });

  final BusinessId businessId;
  final RemoteAuthUserId memberAuthUserId;
  final String role;
  final BusinessScope scope;

  bool get isVerifiedMembership => true;
  String get authUserId => memberAuthUserId.value;
  String get userId => memberAuthUserId.value;
}

abstract interface class BusinessContextProvider {
  BusinessContext? get current;
}
