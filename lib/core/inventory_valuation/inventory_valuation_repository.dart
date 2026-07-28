import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';

abstract class InventoryValuationRepository
    implements TransactionSnapshotProvider {
  Future<ProfitabilityActivation> getActivation();

  Future<List<InventoryValuationState>> listStates();

  Future<InventoryValuationState?> stateForProduct(String productId);

  Future<List<InventoryValuationEvent>> listEvents({String? productId});

  Future<void> activate({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  });

  Future<InventoryValuationEvent?> recordPurchase({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  });

  Future<SaleCostSnapshot?> recordSale({
    required String productId,
    required int quantityKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  });

  Future<InventoryValuationEvent?> reverseSale({
    required String originalValuationEventId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  });

  Future<bool> canDirectlyCancelPurchase(String sourceDocumentId);

  Future<InventoryValuationEvent?> reversePurchase({
    required String originalPurchaseDocumentId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  });

  Future<InventoryValuationEvent?> recordValuedIncrease({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
    required String evidenceReference,
  });

  Future<InventoryValuationEvent?> recordDecrease({
    required String productId,
    required int quantityKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  });
}

abstract class DurableInventoryValuationRepository
    implements InventoryValuationRepository {
  Future<InventoryValuationRestoreData> exportRestoreData();

  Future<void> restoreIntoEmpty(InventoryValuationRestoreData data);

  Future<void> clearForOwnerDataWipe();
}

/// Kept outside [InventoryValuationRepository] so production coordinators do
/// not receive a synthetic activation operation through their normal contract.
abstract class SyntheticTestInventoryValuationRepository {
  Future<void> activateSyntheticForTest({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  });
}

class LocalInventoryValuationRepository
    implements
        DurableInventoryValuationRepository,
        SyntheticTestInventoryValuationRepository {
  ProfitabilityActivation _activation =
      const ProfitabilityActivation.notActivated();
  final Map<String, InventoryValuationState> _states = {};
  final List<InventoryValuationEvent> _events = [];
  int _generatedIdCounter = 0;

  @override
  Future<ProfitabilityActivation> getActivation() async => _activation;

  @override
  Future<List<InventoryValuationState>> listStates() async =>
      List.unmodifiable(_states.values);

  @override
  Future<InventoryValuationState?> stateForProduct(String productId) async =>
      _states[productId];

  @override
  Future<List<InventoryValuationEvent>> listEvents({String? productId}) async =>
      List.unmodifiable(productId == null
          ? _events
          : _events.where((event) => event.productId == productId));

  @override
  Future<void> activate({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  }) =>
      _activate(
        activationDate: activationDate,
        approvedByUserId: approvedByUserId,
        evidenceNote: evidenceNote,
        openings: openings,
        syntheticTest: false,
      );

  @override
  Future<void> activateSyntheticForTest({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  }) =>
      _activate(
        activationDate: activationDate,
        approvedByUserId: approvedByUserId,
        evidenceNote: evidenceNote,
        openings: openings,
        syntheticTest: true,
      );

  Future<void> _activate({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
    required bool syntheticTest,
  }) async {
    if (!_activation.isNotActivated ||
        _states.isNotEmpty ||
        _events.isNotEmpty) {
      throw StateError('Profitability is already activated.');
    }
    final actor = approvedByUserId.trim();
    final note = evidenceNote.trim();
    if (actor.isEmpty || note.isEmpty || openings.isEmpty) {
      throw ArgumentError(
          'Activation actor, evidence and openings are required.');
    }
    final ids = <String>{};
    final now = DateTime.now();
    for (final opening in openings) {
      final productId = opening.productId.trim();
      final evidence = opening.evidenceReference.trim();
      if (productId.isEmpty || !ids.add(productId)) {
        throw ArgumentError('Every opening product must be unique.');
      }
      if (opening.quantityKg < 0 ||
          (opening.quantityKg > 0 && opening.unitCostQirshPerKg <= 0) ||
          evidence.isEmpty) {
        throw ArgumentError(
            'Opening quantity, cost and evidence are required.');
      }
      final value = InventoryCostPrecision.checkedMultiply(
        opening.quantityKg,
        opening.unitCostQirshPerKg,
        'opening value',
      );
      final event = _event(
        productId: productId,
        type: InventoryValuationEventType.openingValuation,
        quantityBeforeKg: 0,
        quantityDeltaKg: opening.quantityKg,
        valueBeforeQirsh: 0,
        valueDeltaQirsh: value,
        unitCostMicrosQirshPerKg: InventoryCostPrecision.checkedMultiply(
          opening.unitCostQirshPerKg,
          InventoryCostPrecision.microsPerQirsh,
          'opening unit cost precision',
        ),
        residualNumerator: 0,
        residualDenominator: 1,
        sourceDocumentId: 'profitability-activation',
        effectiveDate: activationDate,
        createdAt: now,
        createdByUserId: actor,
        evidenceReference: evidence,
      );
      _events.add(event);
      _states[productId] = InventoryValuationState(
        productId: productId,
        quantityKg: opening.quantityKg,
        totalValueQirsh: value,
        updatedAt: now,
        lastEventId: event.id,
      );
    }
    _activation = syntheticTest
        ? ProfitabilityActivation.syntheticTestActivated(
            activationDate: activationDate,
            approvedAt: now,
            approvedByUserId: actor,
            evidenceNote: note,
          )
        : ProfitabilityActivation.activated(
            activationDate: activationDate,
            approvedAt: now,
            approvedByUserId: actor,
            evidenceNote: note,
          );
  }

  @override
  Future<InventoryValuationEvent?> recordPurchase({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  }) =>
      _recordIncrease(
        productId: productId,
        quantityKg: quantityKg,
        unitCostQirshPerKg: unitCostQirshPerKg,
        type: InventoryValuationEventType.purchase,
        sourceDocumentId: sourceDocumentId,
        effectiveDate: effectiveDate,
        createdByUserId: createdByUserId,
      );

  @override
  Future<SaleCostSnapshot?> recordSale({
    required String productId,
    required int quantityKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  }) async {
    if (!_activation.supportsValuationOperations) return null;
    final state = _requiredState(productId);
    _validatePositive(quantityKg, 'sale quantity');
    if (quantityKg > state.quantityKg || state.quantityKg <= 0) {
      throw StateError('Valued stock cannot go below zero.');
    }
    final allocation = quantityKg == state.quantityKg
        ? (state.totalValueQirsh, 0)
        : InventoryCostPrecision.multiplyDivideWithRemainder(
            state.totalValueQirsh,
            quantityKg,
            state.quantityKg,
            'sale cost allocation',
          );
    final cogs = allocation.$1;
    final residual = allocation.$2;
    final now = DateTime.now();
    final event = _event(
      productId: productId,
      type: InventoryValuationEventType.sale,
      quantityBeforeKg: state.quantityKg,
      quantityDeltaKg: -quantityKg,
      valueBeforeQirsh: state.totalValueQirsh,
      valueDeltaQirsh: -cogs,
      unitCostMicrosQirshPerKg: state.unitCostMicrosQirshPerKg,
      residualNumerator: residual,
      residualDenominator: state.quantityKg,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: createdByUserId,
    );
    _apply(event);
    return SaleCostSnapshot(
      valuationEventId: event.id,
      unitCostMicrosQirshPerKg: event.unitCostMicrosQirshPerKg,
      costOfGoodsSoldQirsh: cogs,
      inventoryQuantityBeforeKg: event.quantityBeforeKg,
      inventoryQuantityAfterKg: event.quantityAfterKg,
      inventoryValueBeforeQirsh: event.valueBeforeQirsh,
      inventoryValueAfterQirsh: event.valueAfterQirsh,
      allocationResidualNumerator: event.allocationResidualNumerator,
      allocationResidualDenominator: event.allocationResidualDenominator,
    );
  }

  @override
  Future<InventoryValuationEvent?> reverseSale({
    required String originalValuationEventId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) async {
    if (!_activation.supportsValuationOperations) return null;
    final original = _events.firstWhere(
      (event) => event.id == originalValuationEventId,
      orElse: () => throw StateError('Original sale valuation was not found.'),
    );
    if (original.type != InventoryValuationEventType.sale) {
      throw StateError('Only a sale valuation can be reversed as a sale.');
    }
    _ensureNotReversed(original.id);
    final state = _requiredState(original.productId);
    final now = DateTime.now();
    final event = _event(
      productId: original.productId,
      type: InventoryValuationEventType.saleCancellation,
      quantityBeforeKg: state.quantityKg,
      quantityDeltaKg: -original.quantityDeltaKg,
      valueBeforeQirsh: state.totalValueQirsh,
      valueDeltaQirsh: -original.valueDeltaQirsh,
      unitCostMicrosQirshPerKg: original.unitCostMicrosQirshPerKg,
      residualNumerator: original.allocationResidualNumerator,
      residualDenominator: original.allocationResidualDenominator,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: createdByUserId,
      reversalOfEventId: original.id,
      reason: reason,
    );
    _apply(event);
    return event;
  }

  @override
  Future<bool> canDirectlyCancelPurchase(String sourceDocumentId) async {
    if (!_activation.supportsValuationOperations) return true;
    final purchaseEvents = _events.where((event) =>
        event.type == InventoryValuationEventType.purchase &&
        event.sourceDocumentId == sourceDocumentId);
    if (purchaseEvents.length != 1) return false;
    final purchase = purchaseEvents.single;
    if (_events.any((event) => event.reversalOfEventId == purchase.id)) {
      return false;
    }
    final purchaseIndex =
        _events.indexWhere((event) => event.id == purchase.id);
    if (purchaseIndex < 0) return false;
    return !_events
        .skip(purchaseIndex + 1)
        .any((event) => event.productId == purchase.productId);
  }

  @override
  Future<InventoryValuationEvent?> reversePurchase({
    required String originalPurchaseDocumentId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) async {
    if (!_activation.supportsValuationOperations) return null;
    if (!await canDirectlyCancelPurchase(originalPurchaseDocumentId)) {
      throw StateError(
        'Purchase inventory has been mixed or used; direct cancellation is forbidden.',
      );
    }
    final original = _events.singleWhere((event) =>
        event.type == InventoryValuationEventType.purchase &&
        event.sourceDocumentId == originalPurchaseDocumentId);
    final state = _requiredState(original.productId);
    final quantity = original.quantityDeltaKg;
    final value = original.valueDeltaQirsh;
    if (quantity > state.quantityKg || value > state.totalValueQirsh) {
      throw StateError('Purchase value is no longer fully available.');
    }
    final now = DateTime.now();
    final event = _event(
      productId: original.productId,
      type: InventoryValuationEventType.purchaseCancellation,
      quantityBeforeKg: state.quantityKg,
      quantityDeltaKg: -quantity,
      valueBeforeQirsh: state.totalValueQirsh,
      valueDeltaQirsh: -value,
      unitCostMicrosQirshPerKg: original.unitCostMicrosQirshPerKg,
      residualNumerator: 0,
      residualDenominator: 1,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: createdByUserId,
      reversalOfEventId: original.id,
      reason: reason,
    );
    _apply(event);
    return event;
  }

  @override
  Future<InventoryValuationEvent?> recordValuedIncrease({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
    required String evidenceReference,
  }) {
    if (type != InventoryValuationEventType.stocktakeSurplus &&
        type != InventoryValuationEventType.manualIncrease) {
      throw ArgumentError('Valued increase type is invalid.');
    }
    if (reason.trim().isEmpty || evidenceReference.trim().isEmpty) {
      throw ArgumentError('Increase reason and evidence are required.');
    }
    return _recordIncrease(
      productId: productId,
      quantityKg: quantityKg,
      unitCostQirshPerKg: unitCostQirshPerKg,
      type: type,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdByUserId: createdByUserId,
      reason: reason,
      evidenceReference: evidenceReference,
    );
  }

  @override
  Future<InventoryValuationEvent?> recordDecrease({
    required String productId,
    required int quantityKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) async {
    if (!_activation.supportsValuationOperations) return null;
    if (type != InventoryValuationEventType.stocktakeShortage &&
        type != InventoryValuationEventType.manualDecrease) {
      throw ArgumentError('Valued decrease type is invalid.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Decrease reason is required.');
    }
    final state = _requiredState(productId);
    _validatePositive(quantityKg, 'decrease quantity');
    if (quantityKg > state.quantityKg || state.quantityKg <= 0) {
      throw StateError('Valued stock cannot go below zero.');
    }
    final allocation = quantityKg == state.quantityKg
        ? (state.totalValueQirsh, 0)
        : InventoryCostPrecision.multiplyDivideWithRemainder(
            state.totalValueQirsh,
            quantityKg,
            state.quantityKg,
            'inventory decrease cost allocation',
          );
    final consumed = allocation.$1;
    final residual = allocation.$2;
    final now = DateTime.now();
    final event = _event(
      productId: productId,
      type: type,
      quantityBeforeKg: state.quantityKg,
      quantityDeltaKg: -quantityKg,
      valueBeforeQirsh: state.totalValueQirsh,
      valueDeltaQirsh: -consumed,
      unitCostMicrosQirshPerKg: state.unitCostMicrosQirshPerKg,
      residualNumerator: residual,
      residualDenominator: state.quantityKg,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: createdByUserId,
      reason: reason,
    );
    _apply(event);
    return event;
  }

  Future<InventoryValuationEvent?> _recordIncrease({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    String? reason,
    String? evidenceReference,
  }) async {
    if (!_activation.supportsValuationOperations) return null;
    _validatePositive(quantityKg, 'increase quantity');
    _validatePositive(unitCostQirshPerKg, 'unit cost');
    final state = _states[productId] ??
        InventoryValuationState(
          productId: productId,
          quantityKg: 0,
          totalValueQirsh: 0,
          updatedAt: effectiveDate,
          lastEventId: '',
        );
    final value = InventoryCostPrecision.checkedMultiply(
      quantityKg,
      unitCostQirshPerKg,
      'incoming inventory value',
    );
    final afterQuantity = InventoryCostPrecision.checkedAdd(
      state.quantityKg,
      quantityKg,
      'inventory quantity',
    );
    final afterValue = InventoryCostPrecision.checkedAdd(
      state.totalValueQirsh,
      value,
      'inventory value',
    );
    final now = DateTime.now();
    final scaledAverage = InventoryCostPrecision.multiplyDivideWithRemainder(
      afterValue,
      InventoryCostPrecision.microsPerQirsh,
      afterQuantity,
      'moving weighted average precision',
    );
    final event = _event(
      productId: productId,
      type: type,
      quantityBeforeKg: state.quantityKg,
      quantityDeltaKg: quantityKg,
      valueBeforeQirsh: state.totalValueQirsh,
      valueDeltaQirsh: value,
      unitCostMicrosQirshPerKg: scaledAverage.$1,
      residualNumerator: scaledAverage.$2,
      residualDenominator: afterQuantity,
      sourceDocumentId: sourceDocumentId,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: createdByUserId,
      reason: reason,
      evidenceReference: evidenceReference,
    );
    _apply(event);
    return event;
  }

  InventoryValuationState _requiredState(String productId) {
    final state = _states[productId];
    if (state == null) {
      throw StateError('Product is not included in the approved activation.');
    }
    return state;
  }

  InventoryValuationEvent _event({
    required String productId,
    required InventoryValuationEventType type,
    required int quantityBeforeKg,
    required int quantityDeltaKg,
    required int valueBeforeQirsh,
    required int valueDeltaQirsh,
    required int unitCostMicrosQirshPerKg,
    required int residualNumerator,
    required int residualDenominator,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required DateTime createdAt,
    required String createdByUserId,
    String? reversalOfEventId,
    String? reason,
    String? evidenceReference,
  }) {
    final product = productId.trim();
    final document = sourceDocumentId.trim();
    final actor = createdByUserId.trim();
    if (product.isEmpty || document.isEmpty || actor.isEmpty) {
      throw ArgumentError(
          'Valuation product, document and actor are required.');
    }
    _generatedIdCounter++;
    return InventoryValuationEvent(
      id: 'val-${createdAt.microsecondsSinceEpoch}-$_generatedIdCounter',
      productId: product,
      type: type,
      quantityBeforeKg: quantityBeforeKg,
      quantityDeltaKg: quantityDeltaKg,
      quantityAfterKg: InventoryCostPrecision.checkedSignedAdd(
        quantityBeforeKg,
        quantityDeltaKg,
        'inventory quantity',
      ),
      valueBeforeQirsh: valueBeforeQirsh,
      valueDeltaQirsh: valueDeltaQirsh,
      valueAfterQirsh: InventoryCostPrecision.checkedSignedAdd(
        valueBeforeQirsh,
        valueDeltaQirsh,
        'inventory value',
      ),
      unitCostMicrosQirshPerKg: unitCostMicrosQirshPerKg,
      allocationResidualNumerator: residualNumerator,
      allocationResidualDenominator: residualDenominator,
      sourceDocumentId: document,
      effectiveDate: effectiveDate,
      createdAt: createdAt,
      createdByUserId: actor,
      reversalOfEventId: reversalOfEventId,
      reason: reason?.trim(),
      evidenceReference: evidenceReference?.trim(),
    );
  }

  void _apply(InventoryValuationEvent event) {
    if (event.quantityAfterKg < 0 || event.valueAfterQirsh < 0) {
      throw StateError('Inventory valuation cannot become negative.');
    }
    if ((event.quantityAfterKg == 0) != (event.valueAfterQirsh == 0)) {
      throw StateError('Zero inventory quantity and value must reconcile.');
    }
    _events.add(event);
    _states[event.productId] = InventoryValuationState(
      productId: event.productId,
      quantityKg: event.quantityAfterKg,
      totalValueQirsh: event.valueAfterQirsh,
      updatedAt: event.createdAt,
      lastEventId: event.id,
    );
  }

  void _ensureNotReversed(String eventId) {
    if (_events.any((event) => event.reversalOfEventId == eventId)) {
      throw StateError('Valuation event is already reversed.');
    }
  }

  void _validatePositive(int value, String fieldName) {
    if (value <= 0) throw ArgumentError('$fieldName must be positive.');
  }

  @override
  SnapshotHolder createTransactionSnapshot() => ObjectStateSnapshot<
          (
            ProfitabilityActivation,
            Map<String, InventoryValuationState>,
            List<InventoryValuationEvent>,
            int
          )>(
        captureState: () => (
          _activation,
          Map<String, InventoryValuationState>.from(_states),
          List<InventoryValuationEvent>.from(_events),
          _generatedIdCounter,
        ),
        restoreState: (state) {
          _activation = state.$1;
          _states
            ..clear()
            ..addAll(state.$2);
          _events
            ..clear()
            ..addAll(state.$3);
          _generatedIdCounter = state.$4;
        },
      );

  @override
  Future<InventoryValuationRestoreData> exportRestoreData() async =>
      InventoryValuationRestoreData(
        activation: _activation,
        states: List.unmodifiable(_states.values),
        events: List.unmodifiable(_events),
      );

  @override
  Future<void> restoreIntoEmpty(InventoryValuationRestoreData data) async {
    if (!_activation.isNotActivated ||
        _states.isNotEmpty ||
        _events.isNotEmpty) {
      throw StateError('Inventory valuation repository is not empty.');
    }
    if (!data.activation.supportsValuationOperations &&
        (data.states.isNotEmpty || data.events.isNotEmpty)) {
      throw StateError('Inactive profitability cannot contain valuation data.');
    }
    final ids = <String>{};
    for (final event in data.events) {
      if (!ids.add(event.id)) throw StateError('Duplicate valuation event id.');
    }
    _activation = data.activation;
    _states.addEntries(
        data.states.map((state) => MapEntry(state.productId, state)));
    _events.addAll(data.events);
    for (final event in data.events) {
      final sequence = int.tryParse(event.id.split('-').last) ?? 0;
      if (sequence > _generatedIdCounter) _generatedIdCounter = sequence;
    }
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _activation = const ProfitabilityActivation.notActivated();
    _states.clear();
    _events.clear();
    _generatedIdCounter = 0;
  }
}
