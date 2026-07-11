import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

enum PurchasePaymentMode {
  credit,
  paid,
  partial;

  String get labelAr {
    switch (this) {
      case PurchasePaymentMode.credit:
        return 'آجل على مورد';
      case PurchasePaymentMode.paid:
        return 'مدفوع';
      case PurchasePaymentMode.partial:
        return 'دفع جزئي';
    }
  }
}

class PurchaseIntake {
  const PurchaseIntake({
    required this.id,
    required this.supplierId,
    required this.productId,
    required this.quantityKg,
    required this.entryUnit,
    required this.unitPricePiastersPerKg,
    required this.totalAmountPiasters,
    required this.createdByUserId,
    required this.createdAt,
    required this.stockMovementId,
    this.supplierName,
    this.supplierPhone,
    this.supplierAddress,
    this.notes,
    this.cancellation,
    this.financialAccountId,
    this.paymentMethod,
    this.paymentMode = PurchasePaymentMode.credit,
    this.paidAmountQirsh,
  });

  final String id;
  final String supplierId;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final String productId;
  final int quantityKg;
  final GrainUnit entryUnit;
  final int unitPricePiastersPerKg;
  final int totalAmountPiasters;
  final String createdByUserId;
  final DateTime createdAt;
  final String stockMovementId;
  final String? notes;
  final CancellationMetadata? cancellation;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final PurchasePaymentMode paymentMode;
  final int? paidAmountQirsh;

  int get effectivePaidAmountQirsh {
    if (paidAmountQirsh != null) return paidAmountQirsh!;
    return paymentMode == PurchasePaymentMode.credit ? 0 : totalAmountPiasters;
  }

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;

  PurchaseIntake copyWith({
    String? stockMovementId,
    CancellationMetadata? cancellation,
  }) {
    return PurchaseIntake(
      id: id,
      supplierId: supplierId,
      productId: productId,
      quantityKg: quantityKg,
      entryUnit: entryUnit,
      unitPricePiastersPerKg: unitPricePiastersPerKg,
      totalAmountPiasters: totalAmountPiasters,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      stockMovementId: stockMovementId ?? this.stockMovementId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      supplierAddress: supplierAddress,
      notes: notes,
      cancellation: cancellation ?? this.cancellation,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
      paymentMode: paymentMode,
      paidAmountQirsh: paidAmountQirsh,
    );
  }
}

class PurchaseIntakeDraft {
  const PurchaseIntakeDraft({
    required this.supplierId,
    required this.productId,
    required this.quantityKg,
    required this.entryUnit,
    required this.unitPricePiastersPerKg,
    required this.createdByUserId,
    this.supplierName,
    this.supplierPhone,
    this.supplierAddress,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.paymentMode = PurchasePaymentMode.credit,
    this.paidAmountQirsh,
    this.approvedByUserId,
  });

  final String supplierId;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final String productId;
  final int quantityKg;
  final GrainUnit entryUnit;
  final int unitPricePiastersPerKg;
  final String createdByUserId;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final PurchasePaymentMode paymentMode;
  final int? paidAmountQirsh;
  final String? approvedByUserId;

  int get totalAmountPiasters => quantityKg * unitPricePiastersPerKg;

  int get effectivePaidAmountQirsh {
    if (paidAmountQirsh != null) return paidAmountQirsh!;
    return paymentMode == PurchasePaymentMode.credit ? 0 : totalAmountPiasters;
  }
}
