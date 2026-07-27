import 'dart:async';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftInventoryValuationRepository
    implements DurableInventoryValuationRepository {
  DriftInventoryValuationRepository(this._database);

  static const _activationId = 'profitability';
  final db.FoundationDatabase _database;
  final LocalInventoryValuationRepository _delegate =
      LocalInventoryValuationRepository();
  Future<void> _tail = Future<void>.value();
  bool _loaded = false;

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final completion = Completer<void>();
    final previous = _tail;
    _tail = completion.future;
    await previous.catchError((_) {});
    try {
      return await operation();
    } finally {
      completion.complete();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final activationRow =
        await (_database.select(_database.profitabilityActivations)
              ..where((row) => row.id.equals(_activationId)))
            .getSingleOrNull();
    final stateRows =
        await _database.select(_database.inventoryValuationStates).get();
    final eventRows =
        await (_database.select(_database.inventoryValuationEvents)
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final activation = activationRow == null
        ? const ProfitabilityActivation.notActivated()
        : _activationFromRow(activationRow);
    if (activation.isActivated ||
        stateRows.isNotEmpty ||
        eventRows.isNotEmpty) {
      await _delegate.restoreIntoEmpty(InventoryValuationRestoreData(
        activation: activation,
        states: stateRows.map(_stateFromRow).toList(growable: false),
        events: eventRows.map(_eventFromRow).toList(growable: false),
      ));
    }
    _loaded = true;
  }

  Future<T> _write<T>(Future<T> Function() operation) => _serialized(() async {
        await _ensureLoaded();
        final snapshot = _delegate.createTransactionSnapshot();
        await snapshot.capture();
        try {
          return await _database.inTransaction(() async {
            final result = await operation();
            await _persistAll(await _delegate.exportRestoreData());
            return result;
          });
        } catch (_) {
          await snapshot.rollback();
          rethrow;
        }
      });

  @override
  Future<ProfitabilityActivation> getActivation() => _serialized(() async {
        await _ensureLoaded();
        return _delegate.getActivation();
      });

  @override
  Future<List<InventoryValuationState>> listStates() => _serialized(() async {
        await _ensureLoaded();
        return _delegate.listStates();
      });

  @override
  Future<InventoryValuationState?> stateForProduct(String productId) =>
      _serialized(() async {
        await _ensureLoaded();
        return _delegate.stateForProduct(productId);
      });

  @override
  Future<List<InventoryValuationEvent>> listEvents({String? productId}) =>
      _serialized(() async {
        await _ensureLoaded();
        return _delegate.listEvents(productId: productId);
      });

  @override
  Future<void> activate({
    required DateTime activationDate,
    required String approvedByUserId,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  }) =>
      _write(() => _delegate.activate(
            activationDate: activationDate,
            approvedByUserId: approvedByUserId,
            evidenceNote: evidenceNote,
            openings: openings,
          ));

  @override
  Future<InventoryValuationEvent?> recordPurchase({
    required String productId,
    required int quantityKg,
    required int unitCostQirshPerKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  }) =>
      _write(() => _delegate.recordPurchase(
            productId: productId,
            quantityKg: quantityKg,
            unitCostQirshPerKg: unitCostQirshPerKg,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
          ));

  @override
  Future<SaleCostSnapshot?> recordSale({
    required String productId,
    required int quantityKg,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
  }) =>
      _write(() => _delegate.recordSale(
            productId: productId,
            quantityKg: quantityKg,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
          ));

  @override
  Future<InventoryValuationEvent?> reverseSale({
    required String originalValuationEventId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) =>
      _write(() => _delegate.reverseSale(
            originalValuationEventId: originalValuationEventId,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
            reason: reason,
          ));

  @override
  Future<bool> canDirectlyCancelPurchase(String sourceDocumentId) =>
      _serialized(() async {
        await _ensureLoaded();
        return _delegate.canDirectlyCancelPurchase(sourceDocumentId);
      });

  @override
  Future<InventoryValuationEvent?> reversePurchase({
    required String originalPurchaseDocumentId,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) =>
      _write(() => _delegate.reversePurchase(
            originalPurchaseDocumentId: originalPurchaseDocumentId,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
            reason: reason,
          ));

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
  }) =>
      _write(() => _delegate.recordValuedIncrease(
            productId: productId,
            quantityKg: quantityKg,
            unitCostQirshPerKg: unitCostQirshPerKg,
            type: type,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
            reason: reason,
            evidenceReference: evidenceReference,
          ));

  @override
  Future<InventoryValuationEvent?> recordDecrease({
    required String productId,
    required int quantityKg,
    required InventoryValuationEventType type,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required String reason,
  }) =>
      _write(() => _delegate.recordDecrease(
            productId: productId,
            quantityKg: quantityKg,
            type: type,
            sourceDocumentId: sourceDocumentId,
            effectiveDate: effectiveDate,
            createdByUserId: createdByUserId,
            reason: reason,
          ));

  @override
  Future<InventoryValuationRestoreData> exportRestoreData() =>
      _serialized(() async {
        await _ensureLoaded();
        return _delegate.exportRestoreData();
      });

  @override
  Future<void> restoreIntoEmpty(InventoryValuationRestoreData data) =>
      _serialized(() async {
        await _ensureLoaded();
        final current = await _delegate.exportRestoreData();
        if (current.activation.isActivated ||
            current.states.isNotEmpty ||
            current.events.isNotEmpty) {
          throw StateError('Inventory valuation repository is not empty.');
        }
        final snapshot = _delegate.createTransactionSnapshot();
        await snapshot.capture();
        try {
          await _database.inTransaction(() async {
            await _delegate.restoreIntoEmpty(data);
            await _persistAll(data);
          });
        } catch (_) {
          await snapshot.rollback();
          rethrow;
        }
      });

  @override
  Future<void> clearForOwnerDataWipe() => _serialized(() async {
        await _ensureLoaded();
        await _database.inTransaction(() async {
          await _clearTables();
          await _delegate.clearForOwnerDataWipe();
        });
      });

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _DriftInventoryValuationSnapshot(this);

  Future<void> _persistAll(InventoryValuationRestoreData data) async {
    await _clearTables();
    final activation = data.activation;
    if (activation.isActivated) {
      await _database.profitabilityActivations.insertOne(
        db.ProfitabilityActivationsCompanion.insert(
          id: _activationId,
          status: activation.status.name,
          activationDate: Value(activation.activationDate),
          approvedAt: Value(activation.approvedAt),
          approvedByUserId: Value(activation.approvedByUserId),
          evidenceNote: Value(activation.evidenceNote),
        ),
      );
    }
    for (final state in data.states) {
      await _database.inventoryValuationStates.insertOne(
        db.InventoryValuationStatesCompanion.insert(
          productId: state.productId,
          quantityKg: state.quantityKg,
          totalValueQirsh: state.totalValueQirsh,
          updatedAt: state.updatedAt,
          lastEventId: state.lastEventId,
        ),
      );
    }
    for (final event in data.events) {
      await _database.inventoryValuationEvents
          .insertOne(_eventCompanion(event));
    }
  }

  Future<void> _clearTables() async {
    await _database.delete(_database.inventoryValuationEvents).go();
    await _database.delete(_database.inventoryValuationStates).go();
    await _database.delete(_database.profitabilityActivations).go();
  }

  ProfitabilityActivation _activationFromRow(
    db.ProfitabilityActivationRow row,
  ) {
    if (row.status != ProfitabilityActivationStatus.activated.name ||
        row.activationDate == null ||
        row.approvedAt == null ||
        row.approvedByUserId == null ||
        row.evidenceNote == null) {
      throw StateError('Stored profitability activation is incomplete.');
    }
    return ProfitabilityActivation.activated(
      activationDate: row.activationDate!,
      approvedAt: row.approvedAt!,
      approvedByUserId: row.approvedByUserId!,
      evidenceNote: row.evidenceNote!,
    );
  }

  InventoryValuationState _stateFromRow(
    db.InventoryValuationStateRow row,
  ) =>
      InventoryValuationState(
        productId: row.productId,
        quantityKg: row.quantityKg,
        totalValueQirsh: row.totalValueQirsh,
        updatedAt: row.updatedAt,
        lastEventId: row.lastEventId,
      );

  InventoryValuationEvent _eventFromRow(
    db.InventoryValuationEventRow row,
  ) =>
      InventoryValuationEvent(
        id: row.id,
        productId: row.productId,
        type: InventoryValuationEventType.values.byName(row.eventType),
        quantityBeforeKg: row.quantityBeforeKg,
        quantityDeltaKg: row.quantityDeltaKg,
        quantityAfterKg: row.quantityAfterKg,
        valueBeforeQirsh: row.valueBeforeQirsh,
        valueDeltaQirsh: row.valueDeltaQirsh,
        valueAfterQirsh: row.valueAfterQirsh,
        unitCostMicrosQirshPerKg: row.unitCostMicrosQirshPerKg,
        allocationResidualNumerator: row.allocationResidualNumerator,
        allocationResidualDenominator: row.allocationResidualDenominator,
        sourceDocumentId: row.sourceDocumentId,
        effectiveDate: row.effectiveDate,
        createdAt: row.createdAt,
        createdByUserId: row.createdByUserId,
        reversalOfEventId: row.reversalOfEventId,
        reason: row.reason,
        evidenceReference: row.evidenceReference,
      );

  db.InventoryValuationEventsCompanion _eventCompanion(
    InventoryValuationEvent event,
  ) =>
      db.InventoryValuationEventsCompanion.insert(
        id: event.id,
        productId: event.productId,
        eventType: event.type.name,
        quantityBeforeKg: event.quantityBeforeKg,
        quantityDeltaKg: event.quantityDeltaKg,
        quantityAfterKg: event.quantityAfterKg,
        valueBeforeQirsh: event.valueBeforeQirsh,
        valueDeltaQirsh: event.valueDeltaQirsh,
        valueAfterQirsh: event.valueAfterQirsh,
        unitCostMicrosQirshPerKg: event.unitCostMicrosQirshPerKg,
        allocationResidualNumerator: event.allocationResidualNumerator,
        allocationResidualDenominator: event.allocationResidualDenominator,
        sourceDocumentId: event.sourceDocumentId,
        effectiveDate: event.effectiveDate,
        createdAt: event.createdAt,
        createdByUserId: event.createdByUserId,
        reversalOfEventId: Value(event.reversalOfEventId),
        reason: Value(event.reason),
        evidenceReference: Value(event.evidenceReference),
      );
}

class _DriftInventoryValuationSnapshot extends SnapshotHolder {
  _DriftInventoryValuationSnapshot(this._repository);

  final DriftInventoryValuationRepository _repository;
  InventoryValuationRestoreData? _data;

  @override
  Future<void> capture() async {
    _data = await _repository.exportRestoreData();
  }

  @override
  Future<void> rollback() async {
    final data = _data;
    if (data == null) return;
    await _repository.clearForOwnerDataWipe();
    await _repository.restoreIntoEmpty(data);
  }
}
