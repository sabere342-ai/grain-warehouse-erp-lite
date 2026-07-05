import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';

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
  final String? notes;
  final CancellationMetadata? cancellation;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;

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
    this.createdByUserName,
    this.notes,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
}
