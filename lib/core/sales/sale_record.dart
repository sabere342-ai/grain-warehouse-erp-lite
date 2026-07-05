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

  bool get hasValidId => id.trim().isNotEmpty;
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
