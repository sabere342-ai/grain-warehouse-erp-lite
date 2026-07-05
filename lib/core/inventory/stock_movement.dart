enum StockMovementType {
  openingBalance,
  manualIncrease,
  manualDecrease,
  purchaseIntake,
  sale,
  purchaseCancellation,
  saleCancellation;

  String get labelAr {
    switch (this) {
      case StockMovementType.openingBalance:
        return 'رصيد افتتاحي';
      case StockMovementType.manualIncrease:
        return 'زيادة يدوية';
      case StockMovementType.manualDecrease:
        return 'نقص يدوي';
      case StockMovementType.purchaseIntake:
        return 'استلام شراء';
      case StockMovementType.sale:
        return 'بيع';
      case StockMovementType.purchaseCancellation:
        return 'إلغاء استلام شراء';
      case StockMovementType.saleCancellation:
        return 'إلغاء بيع';
    }
  }

  bool get increasesStock {
    switch (this) {
      case StockMovementType.openingBalance:
      case StockMovementType.manualIncrease:
      case StockMovementType.purchaseIntake:
      case StockMovementType.saleCancellation:
        return true;
      case StockMovementType.manualDecrease:
      case StockMovementType.sale:
      case StockMovementType.purchaseCancellation:
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
    this.originalDocumentId,
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
  final String? originalDocumentId;

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
    this.reversedMovementId,
    this.originalDocumentId,
  });

  final String productId;
  final StockMovementType movementType;
  final int quantityKg;
  final String createdByUserId;
  final String? note;
  final String? reversedMovementId;
  final String? originalDocumentId;
}
