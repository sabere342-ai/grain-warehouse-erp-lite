import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';

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
    this.notes,
    this.cancellation,
  });

  final String id;
  final String supplierId;
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
      notes: notes,
      cancellation: cancellation ?? this.cancellation,
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
    this.notes,
  });

  final String supplierId;
  final String productId;
  final int quantityKg;
  final GrainUnit entryUnit;
  final int unitPricePiastersPerKg;
  final String createdByUserId;
  final String? notes;

  int get totalAmountPiasters => quantityKg * unitPricePiastersPerKg;
}
