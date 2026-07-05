import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Permissions get permissions => Permissions.forRole(role);

  bool get canProceed => isActive && hasValidId;

  bool get hasValidId => id.trim().isNotEmpty;

  Map<String, Object?> toAuthProfileMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role.wireName,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
