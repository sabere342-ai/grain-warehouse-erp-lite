import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

void main() {
  group('role permissions', () {
    test('owner has full access', () {
      const permissions = Permissions.owner;

      expect(permissions.hasFullAccess, isTrue);
      expect(permissions.canAccessSettings, isTrue);
      expect(permissions.canManageProducts, isTrue);
      expect(permissions.canCancelInvoice, isTrue);
      expect(permissions.canCreateStockAdjustment, isTrue);
      expect(permissions.canManageSuppliers, isTrue);
      expect(permissions.canCreatePurchaseIntake, isTrue);
      expect(permissions.canViewAuditLogs, isTrue);
      expect(permissions.canApproveBelowMinimumPrice, isTrue);
    });

    test('employee has restricted access', () {
      const permissions = Permissions.employee;

      expect(permissions.canCreateSale, isTrue);
      expect(permissions.canCreatePurchase, isTrue);
      expect(permissions.canCreateCustomerPayment, isTrue);
      expect(permissions.canCreateExpense, isTrue);
      expect(permissions.canCreateSupplierPayment, isFalse);
      expect(permissions.canAccessSettings, isFalse);
      expect(permissions.canManageProducts, isFalse);
      expect(permissions.canCancelInvoice, isFalse);
      expect(permissions.canCreateStockAdjustment, isFalse);
      expect(permissions.canManageSuppliers, isFalse);
      expect(permissions.canCreatePurchaseIntake, isFalse);
      expect(permissions.canViewAuditLogs, isFalse);
      expect(permissions.canApproveBelowMinimumPrice, isFalse);
    });

    test('settings is owner-only', () {
      expect(Permissions.forRole(UserRole.owner).canAccessSettings, isTrue);
      expect(Permissions.forRole(UserRole.employee).canAccessSettings, isFalse);
    });

    test('employee cannot manage products', () {
      expect(Permissions.employee.canManageProducts, isFalse);
    });

    test('employee cannot cancel invoices', () {
      expect(Permissions.employee.canCancelInvoice, isFalse);
    });

    test('employee cannot create stock adjustment', () {
      expect(Permissions.employee.canCreateStockAdjustment, isFalse);
    });

    test('employee cannot manage suppliers or create purchase intake', () {
      expect(Permissions.employee.canManageSuppliers, isFalse);
      expect(Permissions.employee.canCreatePurchaseIntake, isFalse);
    });

    test('employee cannot view audit logs', () {
      expect(Permissions.employee.canViewAuditLogs, isFalse);
    });
  });

  group('AppUser', () {
    test('inactive user cannot proceed', () {
      final now = DateTime(2026, 1, 1);
      final user = AppUser(
        id: 'inactive-user',
        name: 'موظف غير نشط',
        phone: '01000000002',
        role: UserRole.employee,
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.canProceed, isFalse);
    });

    test('user without id cannot proceed', () {
      final now = DateTime(2026, 1, 1);
      final user = AppUser(
        id: ' ',
        name: 'موظف',
        phone: '01000000002',
        role: UserRole.employee,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.hasValidId, isFalse);
      expect(user.canProceed, isFalse);
    });
  });
}
