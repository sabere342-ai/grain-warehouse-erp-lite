import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';

enum SalePaymentMode {
  cash,
  credit;

  String get labelAr {
    switch (this) {
      case SalePaymentMode.cash:
        return '\u0646\u0642\u062f\u064a';
      case SalePaymentMode.credit:
        return '\u0622\u062c\u0644 \u0639\u0644\u0649 \u0639\u0645\u064a\u0644';
    }
  }
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.totalQirsh,
    required this.createdByUserId,
    required this.createdAt,
    required this.stockMovementId,
    this.paymentMode = SalePaymentMode.cash,
    this.customerId,
    this.createdByUserName,
    this.notes,
    this.cancellation,
  });

  final String id;
  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final int totalQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final String stockMovementId;
  final SalePaymentMode paymentMode;
  final String? customerId;
  final String? notes;
  final CancellationMetadata? cancellation;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;
  bool get isCreditSale => paymentMode == SalePaymentMode.credit;

  SaleRecord copyWith({
    CancellationMetadata? cancellation,
  }) {
    return SaleRecord(
      id: id,
      productId: productId,
      quantityKg: quantityKg,
      salePriceQirshPerKg: salePriceQirshPerKg,
      totalQirsh: totalQirsh,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: createdAt,
      stockMovementId: stockMovementId,
      paymentMode: paymentMode,
      customerId: customerId,
      notes: notes,
      cancellation: cancellation ?? this.cancellation,
    );
  }
}

class SaleDraft {
  const SaleDraft({
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.createdByUserId,
    this.paymentMode = SalePaymentMode.cash,
    this.customerId,
    this.createdByUserName,
    this.notes,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final String createdByUserId;
  final SalePaymentMode paymentMode;
  final String? customerId;
  final String? createdByUserName;
  final String? notes;
}
