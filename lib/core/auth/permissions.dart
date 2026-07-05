import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

class Permissions {
  const Permissions({
    required this.canCreateSale,
    required this.canCreatePurchase,
    required this.canCreateCustomerPayment,
    required this.canCreateSupplierPayment,
    required this.canCreateExpense,
    required this.canCreateStockAdjustment,
    required this.canManageSuppliers,
    required this.canCreatePurchaseIntake,
    required this.canCancelInvoice,
    required this.canManageProducts,
    required this.canViewAuditLogs,
    required this.canAccessSettings,
    required this.canApproveBelowMinimumPrice,
  });

  final bool canCreateSale;
  final bool canCreatePurchase;
  final bool canCreateCustomerPayment;
  final bool canCreateSupplierPayment;
  final bool canCreateExpense;
  final bool canCreateStockAdjustment;
  final bool canManageSuppliers;
  final bool canCreatePurchaseIntake;
  final bool canCancelInvoice;
  final bool canManageProducts;
  final bool canViewAuditLogs;
  final bool canAccessSettings;
  final bool canApproveBelowMinimumPrice;

  static const owner = Permissions(
    canCreateSale: true,
    canCreatePurchase: true,
    canCreateCustomerPayment: true,
    canCreateSupplierPayment: true,
    canCreateExpense: true,
    canCreateStockAdjustment: true,
    canManageSuppliers: true,
    canCreatePurchaseIntake: true,
    canCancelInvoice: true,
    canManageProducts: true,
    canViewAuditLogs: true,
    canAccessSettings: true,
    canApproveBelowMinimumPrice: true,
  );

  static const employee = Permissions(
    canCreateSale: true,
    canCreatePurchase: true,
    canCreateCustomerPayment: true,
    canCreateSupplierPayment: false,
    canCreateExpense: true,
    canCreateStockAdjustment: false,
    canManageSuppliers: false,
    canCreatePurchaseIntake: false,
    canCancelInvoice: false,
    canManageProducts: false,
    canViewAuditLogs: false,
    canAccessSettings: false,
    canApproveBelowMinimumPrice: false,
  );

  factory Permissions.forRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Permissions.owner;
      case UserRole.employee:
        return Permissions.employee;
    }
  }

  bool get hasFullAccess {
    return canCreateSale &&
        canCreatePurchase &&
        canCreateCustomerPayment &&
        canCreateSupplierPayment &&
        canCreateExpense &&
        canCreateStockAdjustment &&
        canManageSuppliers &&
        canCreatePurchaseIntake &&
        canCancelInvoice &&
        canManageProducts &&
        canViewAuditLogs &&
        canAccessSettings &&
        canApproveBelowMinimumPrice;
  }
}
