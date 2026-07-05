import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';

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
    this.notes,
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
  final String? notes;

  bool get hasValidId => id.trim().isNotEmpty;
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
