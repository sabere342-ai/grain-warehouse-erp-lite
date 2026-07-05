enum StockMovementType {
  openingBalance,
  manualIncrease,
  manualDecrease;

  String get labelAr {
    switch (this) {
      case StockMovementType.openingBalance:
        return 'رصيد افتتاحي';
      case StockMovementType.manualIncrease:
        return 'زيادة يدوية';
      case StockMovementType.manualDecrease:
        return 'نقص يدوي';
    }
  }

  bool get increasesStock {
    switch (this) {
      case StockMovementType.openingBalance:
      case StockMovementType.manualIncrease:
        return true;
      case StockMovementType.manualDecrease:
        return false;
    }
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantityKg,
    required this.createdByUserId,
    required this.createdAt,
    this.note,
    this.isVoided = false,
    this.reversedMovementId,
  });

  final String id;
  final String productId;
  final StockMovementType movementType;
  final int quantityKg;
  final String createdByUserId;
  final DateTime createdAt;
  final String? note;
  final bool isVoided;
  final String? reversedMovementId;

  bool get hasValidId => id.trim().isNotEmpty;

  int get signedQuantityKg {
    if (isVoided) {
      return 0;
    }

    return movementType.increasesStock ? quantityKg : -quantityKg;
  }
}

class StockMovementDraft {
  const StockMovementDraft({
    required this.productId,
    required this.movementType,
    required this.quantityKg,
    required this.createdByUserId,
    this.note,
  });

  final String productId;
  final StockMovementType movementType;
  final int quantityKg;
  final String createdByUserId;
  final String? note;
}
