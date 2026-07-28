enum ProfitabilityActivationStatus {
  profitabilityNotActivated,
  syntheticProfitabilityActivatedForTest,
  activated,
}

class ProfitabilityActivation {
  const ProfitabilityActivation.notActivated()
      : status = ProfitabilityActivationStatus.profitabilityNotActivated,
        activationDate = null,
        approvedAt = null,
        approvedByUserId = null,
        evidenceNote = null;

  const ProfitabilityActivation.activated({
    required this.activationDate,
    required this.approvedAt,
    required this.approvedByUserId,
    required this.evidenceNote,
  }) : status = ProfitabilityActivationStatus.activated;

  const ProfitabilityActivation.syntheticTestActivated({
    required this.activationDate,
    required this.approvedAt,
    required this.approvedByUserId,
    required this.evidenceNote,
  }) : status = ProfitabilityActivationStatus
            .syntheticProfitabilityActivatedForTest;

  final ProfitabilityActivationStatus status;
  final DateTime? activationDate;
  final DateTime? approvedAt;
  final String? approvedByUserId;
  final String? evidenceNote;

  bool get isActivated => status == ProfitabilityActivationStatus.activated;

  bool get isSyntheticTestActivated =>
      status ==
      ProfitabilityActivationStatus.syntheticProfitabilityActivatedForTest;

  bool get supportsValuationOperations =>
      isActivated || isSyntheticTestActivated;

  bool get isNotActivated =>
      status == ProfitabilityActivationStatus.profitabilityNotActivated;
}

class OpeningValuationInput {
  const OpeningValuationInput({
    required this.productId,
    required this.quantityKg,
    required this.unitCostQirshPerKg,
    required this.evidenceReference,
  });

  final String productId;
  final int quantityKg;
  final int unitCostQirshPerKg;
  final String evidenceReference;
}

class InventoryValuationState {
  const InventoryValuationState({
    required this.productId,
    required this.quantityKg,
    required this.totalValueQirsh,
    required this.updatedAt,
    required this.lastEventId,
  });

  final String productId;
  final int quantityKg;
  final int totalValueQirsh;
  final DateTime updatedAt;
  final String lastEventId;

  int get unitCostMicrosQirshPerKg => quantityKg == 0
      ? 0
      : InventoryCostPrecision.multiplyDivideWithRemainder(
          totalValueQirsh,
          InventoryCostPrecision.microsPerQirsh,
          quantityKg,
          'inventory average unit cost',
        ).$1;
}

enum InventoryValuationEventType {
  openingValuation,
  purchase,
  sale,
  saleCancellation,
  purchaseCancellation,
  stocktakeShortage,
  stocktakeSurplus,
  manualIncrease,
  manualDecrease,
}

class InventoryValuationEvent {
  const InventoryValuationEvent({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantityBeforeKg,
    required this.quantityDeltaKg,
    required this.quantityAfterKg,
    required this.valueBeforeQirsh,
    required this.valueDeltaQirsh,
    required this.valueAfterQirsh,
    required this.unitCostMicrosQirshPerKg,
    required this.allocationResidualNumerator,
    required this.allocationResidualDenominator,
    required this.sourceDocumentId,
    required this.effectiveDate,
    required this.createdAt,
    required this.createdByUserId,
    this.reversalOfEventId,
    this.reason,
    this.evidenceReference,
  });

  final String id;
  final String productId;
  final InventoryValuationEventType type;
  final int quantityBeforeKg;
  final int quantityDeltaKg;
  final int quantityAfterKg;
  final int valueBeforeQirsh;
  final int valueDeltaQirsh;
  final int valueAfterQirsh;
  final int unitCostMicrosQirshPerKg;
  final int allocationResidualNumerator;
  final int allocationResidualDenominator;
  final String sourceDocumentId;
  final DateTime effectiveDate;
  final DateTime createdAt;
  final String createdByUserId;
  final String? reversalOfEventId;
  final String? reason;
  final String? evidenceReference;

  int get costOfGoodsSoldQirsh =>
      type == InventoryValuationEventType.sale ? -valueDeltaQirsh : 0;
}

class SaleCostSnapshot {
  const SaleCostSnapshot({
    required this.valuationEventId,
    required this.unitCostMicrosQirshPerKg,
    required this.costOfGoodsSoldQirsh,
    required this.inventoryQuantityBeforeKg,
    required this.inventoryQuantityAfterKg,
    required this.inventoryValueBeforeQirsh,
    required this.inventoryValueAfterQirsh,
    required this.allocationResidualNumerator,
    required this.allocationResidualDenominator,
  });

  final String valuationEventId;
  final int unitCostMicrosQirshPerKg;
  final int costOfGoodsSoldQirsh;
  final int inventoryQuantityBeforeKg;
  final int inventoryQuantityAfterKg;
  final int inventoryValueBeforeQirsh;
  final int inventoryValueAfterQirsh;
  final int allocationResidualNumerator;
  final int allocationResidualDenominator;
}

class InventoryValuationRestoreData {
  const InventoryValuationRestoreData({
    required this.activation,
    required this.states,
    required this.events,
  });

  final ProfitabilityActivation activation;
  final List<InventoryValuationState> states;
  final List<InventoryValuationEvent> events;
}

class InventoryCostPrecision {
  const InventoryCostPrecision._();

  static const int microsPerQirsh = 1000000;
  static const int minInt64 = -9223372036854775808;
  static const int maxInt64 = 9223372036854775807;

  static int checkedMultiply(int left, int right, String fieldName) {
    if (left < 0 || right < 0) {
      throw ArgumentError('$fieldName values must not be negative.');
    }
    if (left != 0 && right > maxInt64 ~/ left) {
      throw ArgumentError('$fieldName exceeds the supported integer range.');
    }
    return left * right;
  }

  static int checkedAdd(int left, int right, String fieldName) {
    if (left < 0 || right < 0 || left > maxInt64 - right) {
      throw ArgumentError('$fieldName exceeds the supported integer range.');
    }
    return left + right;
  }

  static int checkedSignedAdd(int left, int right, String fieldName) {
    final value = BigInt.from(left) + BigInt.from(right);
    if (value < BigInt.from(minInt64) || value > BigInt.from(maxInt64)) {
      throw ArgumentError('$fieldName exceeds the supported integer range.');
    }
    return value.toInt();
  }

  static (int, int) multiplyDivideWithRemainder(
    int left,
    int right,
    int denominator,
    String fieldName,
  ) {
    if (left < 0 || right < 0 || denominator <= 0) {
      throw ArgumentError('$fieldName values are invalid.');
    }
    final divisor = BigInt.from(denominator);
    final numerator = BigInt.from(left) * BigInt.from(right);
    final quotient = numerator ~/ divisor;
    final remainder = numerator.remainder(divisor);
    if (quotient > BigInt.from(maxInt64)) {
      throw ArgumentError('$fieldName exceeds the supported integer range.');
    }
    return (quotient.toInt(), remainder.toInt());
  }
}
