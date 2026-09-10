import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

final class DriftInternalTransferPostingAttemptStore
    implements DurableInternalTransferPostingAttemptStore {
  DriftInternalTransferPostingAttemptStore(
    db.FoundationDatabase database, {
    ApplicationClock clock = const SystemApplicationClock(),
    DriftDurableSyncStore? durableSyncStore,
  })  : _database = database,
        _clock = clock,
        _durableSyncStore =
            durableSyncStore ?? DriftDurableSyncStore(database, clock: clock);

  final db.FoundationDatabase _database;
  final ApplicationClock _clock;
  final DriftDurableSyncStore _durableSyncStore;
  static const _operationKind = 'financial.internalTransfer.post.v1';

  @override
  Future<InternalTransferPostingAttempt> prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
  }) =>
      _prepare(
        commandId: commandId,
        businessId: businessId,
        canonicalPayloadJson: canonicalPayloadJson,
        localFingerprint: localFingerprint,
      );

  @override
  Future<InternalTransferPostingAttempt> prepareDurable({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
    required ExecutionContext executionContext,
    required BusinessDate businessDate,
  }) =>
      _prepare(
        commandId: commandId,
        businessId: businessId,
        canonicalPayloadJson: canonicalPayloadJson,
        localFingerprint: localFingerprint,
        executionContext: executionContext,
        businessDate: businessDate,
      );

  Future<InternalTransferPostingAttempt> _prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
    ExecutionContext? executionContext,
    BusinessDate? businessDate,
  }) =>
      _database.inTransaction(() async {
        final existing = await load(commandId);
        if (existing != null) {
          if (existing.businessId != businessId ||
              existing.canonicalPayloadJson != canonicalPayloadJson ||
              existing.localFingerprint != localFingerprint) {
            throw const InternalTransferPostingAttemptConflictException();
          }
          return existing;
        }
        if (executionContext != null && businessDate != null) {
          try {
            return _genericDomain(await _durableSyncStore.enqueue(
              DurableOutboxEnvelope.fromExecutionContext(
                operationId: OperationId(commandId),
                idempotencyKey: commandId,
                context: executionContext,
                operationKind: _operationKind,
                aggregateType: 'financialTransfer',
                payloadSchemaVersion: 1,
                payloadJson: canonicalPayloadJson,
                payloadFingerprint: localFingerprint,
                occurredAtUtc:
                    requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc'),
                businessDate: businessDate,
              ),
            ));
          } on DurableIdentityConflictException {
            throw const InternalTransferPostingAttemptConflictException();
          }
        }
        final now = requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc');
        await _database.into(_database.internalTransferPostingAttempts).insert(
              db.InternalTransferPostingAttemptsCompanion.insert(
                commandId: commandId,
                businessId: businessId,
                canonicalPayloadJson: canonicalPayloadJson,
                localFingerprint: localFingerprint,
                lifecycleState: InternalTransferPostingAttemptState.queued.name,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        return (await _loadLegacy(commandId))!;
      });

  @override
  Future<InternalTransferPostingAttempt?> load(String commandId) async =>
      await _loadLegacy(commandId) ?? await _generic(commandId);

  Future<InternalTransferPostingAttempt?> _loadLegacy(String commandId) async {
    final row =
        await (_database.select(_database.internalTransferPostingAttempts)
              ..where((table) => table.commandId.equals(commandId)))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<InternalTransferPostingAttempt>> loadIncompleteForBusiness(
    String businessId,
  ) async {
    final legacy =
        await (_database.select(_database.internalTransferPostingAttempts)
              ..where((table) =>
                  table.businessId.equals(businessId) &
                  table.lifecycleState.isNotIn(<String>[
                    InternalTransferPostingAttemptState.confirmed.name,
                    InternalTransferPostingAttemptState.rejected.name,
                  ])))
            .get();
    final ids = await (_database.selectOnly(_database.durableOutboxOperations)
          ..addColumns([_database.durableOutboxOperations.operationId])
          ..where(
              _database.durableOutboxOperations.businessId.equals(businessId) &
                  _database.durableOutboxOperations.operationKind
                      .equals(_operationKind) &
                  _database.durableOutboxOperations.state.isNotIn(<String>[
                    DurableOutboxState.completed.name,
                    DurableOutboxState.permanentFailure.name,
                    DurableOutboxState.cancelled.name,
                  ])))
        .get();
    final result = legacy.map(_toDomain).toList();
    for (final row in ids) {
      final value = await _generic(
        row.read(_database.durableOutboxOperations.operationId)!,
      );
      if (value != null) result.add(value);
    }
    result.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return List.unmodifiable(result);
  }

  @override
  Future<void> markSending(String commandId) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      await _durableSyncStore.claimOutbox(
        generic.envelope.scope,
        commandId,
        nowUtc: requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc'),
        leaseDuration: const Duration(minutes: 5),
      );
      return;
    }
    final current = await _required(commandId);
    await _updateLegacy(commandId,
        state: InternalTransferPostingAttemptState.sending,
        attemptCount: current.attemptCount + 1,
        clearError: true);
  }

  @override
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  ) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      if (generic.state == DurableOutboxState.acknowledgedPendingApply ||
          generic.state == DurableOutboxState.completed) {
        if (generic.acknowledgement?.payloadJson != canonicalServerResultJson) {
          throw const InternalTransferPostingAttemptConflictException();
        }
        return;
      }
      await _durableSyncStore.acknowledgeOutbox(
        generic.envelope.scope,
        commandId,
        expectedRecordVersion: generic.recordVersion,
        claimToken: generic.claimToken!,
        acknowledgement: DurableAcknowledgement(
          schemaVersion: 1,
          payloadJson: canonicalServerResultJson,
          payloadFingerprint: payloadFingerprint(canonicalServerResultJson),
          serverAcceptedAtUtc: _serverAcceptedAt(canonicalServerResultJson),
        ),
      );
      return;
    }
    await _updateLegacy(commandId,
        state: InternalTransferPostingAttemptState.confirmedProjectionPending,
        canonicalServerResultJson: canonicalServerResultJson,
        clearError: true);
  }

  @override
  Future<void> markConfirmed(String commandId) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      if (generic.state == DurableOutboxState.completed) return;
      await _durableSyncStore.completeOutbox(generic.envelope.scope, commandId,
          expectedRecordVersion: generic.recordVersion);
      return;
    }
    await _updateLegacy(commandId,
        state: InternalTransferPostingAttemptState.confirmed, clearError: true);
  }

  @override
  Future<void> markFailure(
    String commandId, {
    required InternalTransferPostingAttemptState state,
    required String errorCode,
  }) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      if (generic.state == DurableOutboxState.conflict) return;
      if (generic.state == DurableOutboxState.acknowledgedPendingApply &&
          state ==
              InternalTransferPostingAttemptState.confirmedProjectionPending) {
        return;
      }
      if (generic.state != DurableOutboxState.claimed ||
          generic.claimToken == null) {
        throw const DurableLostRaceException();
      }
      if (state == InternalTransferPostingAttemptState.rejected) {
        await _durableSyncStore.failOutboxPermanently(
          generic.envelope.scope,
          commandId,
          expectedRecordVersion: generic.recordVersion,
          claimToken: generic.claimToken!,
          errorClass: DurableErrorClass.businessRule,
          errorCode: errorCode,
        );
      } else {
        await _durableSyncStore.retryOutbox(
          generic.envelope.scope,
          commandId,
          expectedRecordVersion: generic.recordVersion,
          claimToken: generic.claimToken!,
          nextAttemptAtUtc: requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc'),
          errorClass: DurableErrorClass.unknownOutcome,
          errorCode: errorCode,
        );
      }
      return;
    }
    await _updateLegacy(commandId, state: state, lastErrorCode: errorCode);
  }

  Future<void> _updateLegacy(
    String commandId, {
    required InternalTransferPostingAttemptState state,
    String? canonicalServerResultJson,
    int? attemptCount,
    String? lastErrorCode,
    bool clearError = false,
  }) async {
    final affected =
        await (_database.update(_database.internalTransferPostingAttempts)
              ..where((table) => table.commandId.equals(commandId)))
            .write(db.InternalTransferPostingAttemptsCompanion(
      lifecycleState: Value(state.name),
      canonicalServerResultJson: canonicalServerResultJson == null
          ? const Value.absent()
          : Value(canonicalServerResultJson),
      updatedAtUtc: Value(requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc')),
      attemptCount:
          attemptCount == null ? const Value.absent() : Value(attemptCount),
      lastErrorCode: clearError
          ? const Value(null)
          : lastErrorCode == null
              ? const Value.absent()
              : Value(lastErrorCode),
    ));
    if (affected != 1) {
      throw StateError('Internal transfer posting attempt is missing.');
    }
  }

  Future<InternalTransferPostingAttempt> _required(String commandId) async {
    final value = await load(commandId);
    if (value == null) {
      throw StateError('Internal transfer posting attempt is missing.');
    }
    return value;
  }

  Future<DurableOutboxOperation?> _genericOperation(String commandId) async {
    final value = await _durableSyncStore
        .loadOutboxByOperationIdForCompatibility(commandId);
    return value?.envelope.operationKind == _operationKind ? value : null;
  }

  Future<InternalTransferPostingAttempt?> _generic(String commandId) async {
    final value = await _genericOperation(commandId);
    return value == null ? null : _genericDomain(value);
  }

  InternalTransferPostingAttempt _genericDomain(DurableOutboxOperation value) =>
      InternalTransferPostingAttempt(
        commandId: value.envelope.operationId.value,
        businessId: value.envelope.scope.businessId.value,
        canonicalPayloadJson: value.envelope.payloadJson,
        localFingerprint: value.envelope.payloadFingerprint,
        state: switch (value.state) {
          DurableOutboxState.pending =>
            InternalTransferPostingAttemptState.queued,
          DurableOutboxState.claimed =>
            InternalTransferPostingAttemptState.sending,
          DurableOutboxState.retryWait =>
            InternalTransferPostingAttemptState.unknownOutcome,
          DurableOutboxState.acknowledgedPendingApply =>
            InternalTransferPostingAttemptState.confirmedProjectionPending,
          DurableOutboxState.completed =>
            InternalTransferPostingAttemptState.confirmed,
          DurableOutboxState.permanentFailure ||
          DurableOutboxState.cancelled ||
          DurableOutboxState.conflict =>
            InternalTransferPostingAttemptState.rejected,
        },
        canonicalServerResultJson: value.acknowledgement?.payloadJson,
        createdAtUtc: value.createdAtUtc,
        updatedAtUtc: value.updatedAtUtc,
        attemptCount: value.attemptCount,
        lastErrorCode: value.lastErrorCode,
      );

  DateTime _serverAcceptedAt(String payload) {
    final value = (jsonDecode(payload)
        as Map<String, dynamic>)['serverAcceptedAtUtc'] as String?;
    return value == null
        ? requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc')
        : requireUtcInstant(
            DateTime.parse(value).toUtc(), 'serverAcceptedAtUtc');
  }

  InternalTransferPostingAttempt _toDomain(
    db.InternalTransferPostingAttemptRow row,
  ) =>
      InternalTransferPostingAttempt(
        commandId: row.commandId,
        businessId: row.businessId,
        canonicalPayloadJson: row.canonicalPayloadJson,
        localFingerprint: row.localFingerprint,
        state: InternalTransferPostingAttemptState.values.byName(
          row.lifecycleState,
        ),
        canonicalServerResultJson: row.canonicalServerResultJson,
        createdAtUtc: row.createdAtUtc.toUtc(),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
        attemptCount: row.attemptCount,
        lastErrorCode: row.lastErrorCode,
      );
}
