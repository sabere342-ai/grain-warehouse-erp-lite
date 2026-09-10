import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_inbox_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_outbox_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_sync_checkpoint_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_sync_transaction_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:uuid/uuid.dart';

final class DriftDurableSyncStore
    implements
        DurableOutboxRepository,
        DurableInboxRepository,
        DurableConflictRepository,
        DurableSyncCheckpointRepository,
        DurableSyncTransactionCoordinator {
  DriftDurableSyncStore(
    this.database, {
    ApplicationClock clock = const SystemApplicationClock(),
  }) : _clock = clock;

  final db.FoundationDatabase database;
  final ApplicationClock _clock;

  DateTime _now() => requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc');

  @override
  Future<DurableOutboxOperation> enqueue(DurableOutboxEnvelope envelope) =>
      database.inTransaction(() => _enqueue(envelope));

  Future<DurableOutboxOperation> _enqueue(
    DurableOutboxEnvelope envelope,
  ) async {
    final existing = await (database.select(database.durableOutboxOperations)
          ..where(
              (table) => table.operationId.equals(envelope.operationId.value)))
        .getSingleOrNull();
    if (existing != null) {
      if (!_sameOutboxEnvelope(existing, envelope)) {
        throw const DurableIdentityConflictException(
          'outboundIdentityMismatch',
        );
      }
      return _outbox(existing);
    }
    final now = _now();
    try {
      await database.into(database.durableOutboxOperations).insert(
            db.DurableOutboxOperationsCompanion.insert(
              operationId: envelope.operationId.value,
              idempotencyKey: envelope.idempotencyKey,
              businessId: envelope.scope.businessId.value,
              scopeKind: envelope.scope.kind.name,
              warehouseId: Value(envelope.scope.warehouseId?.value),
              actorAuthUserId: envelope.actorAuthUserId.value,
              deviceId: envelope.deviceId.value,
              sessionId: envelope.sessionId.value,
              capturedRole: envelope.capturedRole,
              operationKind: envelope.operationKind,
              aggregateType: envelope.aggregateType,
              aggregateId: Value(envelope.aggregateId),
              payloadSchemaVersion: envelope.payloadSchemaVersion,
              payloadJson: envelope.payloadJson,
              payloadFingerprint: envelope.payloadFingerprint,
              baseEntityVersion: Value(envelope.baseEntityVersion?.value),
              isDeletionIntent: Value(envelope.isDeletionIntent),
              occurredAtUtc: envelope.occurredAtUtc,
              businessDate: Value(envelope.businessDate?.value),
              causalPredecessorOperationId:
                  Value(envelope.causalPredecessorOperationId?.value),
              state: DurableOutboxState.pending.name,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
    } on Object catch (error) {
      final raced = await (database.select(database.durableOutboxOperations)
            ..where((table) =>
                table.operationId.equals(envelope.operationId.value)))
          .getSingleOrNull();
      if (raced != null && _sameOutboxEnvelope(raced, envelope)) {
        return _outbox(raced);
      }
      throw DurableIdentityConflictException(
        error.toString().contains('idempotency')
            ? 'idempotencyKeyConflict'
            : 'outboundIdentityMismatch',
      );
    }
    return (await loadOutbox(envelope.scope, envelope.operationId.value))!;
  }

  @override
  Future<T> enqueueWithMutation<T>(
    DurableOutboxEnvelope envelope,
    Future<T> Function() mutation,
  ) =>
      database.inTransaction(() async {
        final value = await mutation();
        await _enqueue(envelope);
        return value;
      });

  @override
  Future<DurableOutboxOperation?> loadOutbox(
    DurableScope scope,
    String operationId,
  ) async {
    final row = await (database.select(database.durableOutboxOperations)
          ..where((table) =>
              table.operationId.equals(operationId) &
              _outboxScope(table, scope)))
        .getSingleOrNull();
    return row == null ? null : _outbox(row);
  }

  /// Compatibility seam for command stores that predate scoped load APIs.
  /// The caller must still validate the returned operation kind and scope.
  Future<DurableOutboxOperation?> loadOutboxByOperationIdForCompatibility(
    String operationId,
  ) async {
    final row = await (database.select(database.durableOutboxOperations)
          ..where((table) => table.operationId.equals(operationId)))
        .getSingleOrNull();
    return row == null ? null : _outbox(row);
  }

  Future<DurableOutboxOperation> claimOutbox(
    DurableScope scope,
    String operationId, {
    required DateTime nowUtc,
    required Duration leaseDuration,
  }) =>
      database.inTransaction(() async {
        requireUtcInstant(nowUtc, 'nowUtc');
        if (leaseDuration <= Duration.zero) {
          throw ArgumentError.value(leaseDuration, 'leaseDuration');
        }
        final current = await loadOutbox(scope, operationId);
        if (current == null ||
            (current.state != DurableOutboxState.pending &&
                (current.state != DurableOutboxState.retryWait ||
                    current.nextAttemptAtUtc == null ||
                    current.nextAttemptAtUtc!.isAfter(nowUtc)))) {
          throw const DurableLostRaceException();
        }
        final predecessor = current.envelope.causalPredecessorOperationId;
        if (predecessor != null) {
          final dependency = await loadOutbox(scope, predecessor.value);
          if (dependency?.state != DurableOutboxState.completed) {
            throw const DurableLostRaceException();
          }
        }
        final token = const Uuid().v4();
        final affected =
            await (database.update(database.durableOutboxOperations)
                  ..where((table) =>
                      table.operationId.equals(operationId) &
                      _outboxScope(table, scope) &
                      table.recordVersion.equals(current.recordVersion) &
                      table.state.equals(current.state.name)))
                .write(
          db.DurableOutboxOperationsCompanion(
            state: Value(DurableOutboxState.claimed.name),
            attemptCount: Value(current.attemptCount + 1),
            lastAttemptAtUtc: Value(nowUtc),
            nextAttemptAtUtc: const Value(null),
            lastErrorClass: const Value(null),
            lastErrorCode: const Value(null),
            claimToken: Value(token),
            leaseExpiresAtUtc: Value(nowUtc.add(leaseDuration)),
            updatedAtUtc: Value(nowUtc),
            recordVersion: Value(current.recordVersion + 1),
          ),
        );
        if (affected != 1) throw const DurableLostRaceException();
        return (await loadOutbox(scope, operationId))!;
      });

  @override
  Future<List<DurableOutboxOperation>> listEligibleOutbox(
    DurableScope scope,
    DateTime nowUtc,
  ) async {
    requireUtcInstant(nowUtc, 'nowUtc');
    final rows = await (database.select(database.durableOutboxOperations)
          ..where((table) =>
              _outboxScope(table, scope) &
              (table.state.equals(DurableOutboxState.pending.name) |
                  (table.state.equals(DurableOutboxState.retryWait.name) &
                      table.nextAttemptAtUtc.isSmallerOrEqualValue(nowUtc))))
          ..orderBy([
            (table) => OrderingTerm.asc(table.nextAttemptAtUtc),
            (table) => OrderingTerm.asc(table.createdAtUtc),
            (table) => OrderingTerm.asc(table.operationId),
          ]))
        .get();
    final eligible = <DurableOutboxOperation>[];
    for (final row in rows) {
      final predecessor = row.causalPredecessorOperationId;
      if (predecessor != null) {
        final dependency =
            await (database.select(database.durableOutboxOperations)
                  ..where((table) =>
                      table.operationId.equals(predecessor) &
                      _outboxScope(table, scope) &
                      table.state.equals(DurableOutboxState.completed.name)))
                .getSingleOrNull();
        if (dependency == null) continue;
      }
      eligible.add(_outbox(row));
    }
    return List.unmodifiable(eligible);
  }

  @override
  Future<DurableOutboxOperation?> claimNextOutbox(
    DurableScope scope, {
    required DateTime nowUtc,
    required Duration leaseDuration,
  }) =>
      database.inTransaction(() async {
        requireUtcInstant(nowUtc, 'nowUtc');
        if (leaseDuration <= Duration.zero) {
          throw ArgumentError.value(leaseDuration, 'leaseDuration');
        }
        final candidates = await listEligibleOutbox(scope, nowUtc);
        for (final candidate in candidates) {
          final token = const Uuid().v4();
          final affected =
              await (database.update(database.durableOutboxOperations)
                    ..where((table) =>
                        table.operationId
                            .equals(candidate.envelope.operationId.value) &
                        _outboxScope(table, scope) &
                        table.recordVersion.equals(candidate.recordVersion) &
                        table.state.equals(candidate.state.name)))
                  .write(
            db.DurableOutboxOperationsCompanion(
              state: Value(DurableOutboxState.claimed.name),
              attemptCount: Value(candidate.attemptCount + 1),
              lastAttemptAtUtc: Value(nowUtc),
              nextAttemptAtUtc: const Value(null),
              lastErrorClass: const Value(null),
              lastErrorCode: const Value(null),
              claimToken: Value(token),
              leaseExpiresAtUtc: Value(nowUtc.add(leaseDuration)),
              updatedAtUtc: Value(nowUtc),
              recordVersion: Value(candidate.recordVersion + 1),
            ),
          );
          if (affected == 1) {
            return loadOutbox(scope, candidate.envelope.operationId.value);
          }
        }
        return null;
      });

  @override
  Future<void> retryOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DateTime nextAttemptAtUtc,
    required DurableErrorClass errorClass,
    required String errorCode,
  }) async {
    requireUtcInstant(nextAttemptAtUtc, 'nextAttemptAtUtc');
    _stableCode(errorCode);
    final now = _now();
    final affected = await (database.update(database.durableOutboxOperations)
          ..where((table) =>
              table.operationId.equals(operationId) &
              _outboxScope(table, scope) &
              table.state.equals(DurableOutboxState.claimed.name) &
              table.recordVersion.equals(expectedRecordVersion) &
              table.claimToken.equals(claimToken) &
              table.leaseExpiresAtUtc.isBiggerThanValue(now)))
        .write(
      db.DurableOutboxOperationsCompanion(
        state: Value(DurableOutboxState.retryWait.name),
        nextAttemptAtUtc: Value(nextAttemptAtUtc),
        lastErrorClass: Value(errorClass.name),
        lastErrorCode: Value(errorCode),
        claimToken: const Value(null),
        leaseExpiresAtUtc: const Value(null),
        updatedAtUtc: Value(now),
        recordVersion: Value(expectedRecordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  @override
  Future<void> acknowledgeOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableAcknowledgement acknowledgement,
  }) async {
    final now = _now();
    final affected = await (database.update(database.durableOutboxOperations)
          ..where((table) =>
              table.operationId.equals(operationId) &
              _outboxScope(table, scope) &
              table.state.equals(DurableOutboxState.claimed.name) &
              table.recordVersion.equals(expectedRecordVersion) &
              table.claimToken.equals(claimToken) &
              table.leaseExpiresAtUtc.isBiggerThanValue(now)))
        .write(
      db.DurableOutboxOperationsCompanion(
        state: Value(DurableOutboxState.acknowledgedPendingApply.name),
        claimToken: const Value(null),
        leaseExpiresAtUtc: const Value(null),
        ackSchemaVersion: Value(acknowledgement.schemaVersion),
        ackPayloadJson: Value(acknowledgement.payloadJson),
        ackPayloadFingerprint: Value(acknowledgement.payloadFingerprint),
        serverResultId: Value(acknowledgement.serverResultId),
        serverAcceptedAtUtc: Value(acknowledgement.serverAcceptedAtUtc),
        acknowledgedEntityVersion:
            Value(acknowledgement.acknowledgedEntityVersion?.value),
        lastErrorClass: const Value(null),
        lastErrorCode: const Value(null),
        updatedAtUtc: Value(now),
        recordVersion: Value(expectedRecordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  @override
  Future<void> completeOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
  }) async {
    final now = _now();
    final affected = await (database.update(database.durableOutboxOperations)
          ..where((table) =>
              table.operationId.equals(operationId) &
              _outboxScope(table, scope) &
              table.state
                  .equals(DurableOutboxState.acknowledgedPendingApply.name) &
              table.recordVersion.equals(expectedRecordVersion)))
        .write(
      db.DurableOutboxOperationsCompanion(
        state: Value(DurableOutboxState.completed.name),
        updatedAtUtc: Value(now),
        recordVersion: Value(expectedRecordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  Future<void> failOutboxPermanently(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableErrorClass errorClass,
    required String errorCode,
  }) async {
    _stableCode(errorCode);
    final now = _now();
    final affected = await (database.update(database.durableOutboxOperations)
          ..where((table) =>
              table.operationId.equals(operationId) &
              _outboxScope(table, scope) &
              table.state.equals(DurableOutboxState.claimed.name) &
              table.recordVersion.equals(expectedRecordVersion) &
              table.claimToken.equals(claimToken) &
              table.leaseExpiresAtUtc.isBiggerThanValue(now)))
        .write(
      db.DurableOutboxOperationsCompanion(
        state: Value(DurableOutboxState.permanentFailure.name),
        claimToken: const Value(null),
        leaseExpiresAtUtc: const Value(null),
        lastErrorClass: Value(errorClass.name),
        lastErrorCode: Value(errorCode),
        updatedAtUtc: Value(now),
        recordVersion: Value(expectedRecordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  @override
  Future<int> recoverExpiredOutboxClaims(DateTime nowUtc) {
    requireUtcInstant(nowUtc, 'nowUtc');
    return database.customUpdate(
      'UPDATE durable_outbox_operations SET state = ?, next_attempt_at_utc = ?, '
      'last_error_class = ?, last_error_code = ?, claim_token = NULL, '
      'lease_expires_at_utc = NULL, updated_at_utc = ?, '
      'record_version = record_version + 1 '
      'WHERE state = ? AND lease_expires_at_utc <= ?',
      variables: <Variable<Object>>[
        Variable<String>(DurableOutboxState.retryWait.name),
        Variable<DateTime>(nowUtc),
        Variable<String>(DurableErrorClass.staleClaimRecovered.name),
        const Variable<String>('staleClaimRecovered'),
        Variable<DateTime>(nowUtc),
        Variable<String>(DurableOutboxState.claimed.name),
        Variable<DateTime>(nowUtc),
      ],
      updates: {database.durableOutboxOperations},
    );
  }

  @override
  Future<DurableInboxOperation> receive(DurableInboxEnvelope envelope) =>
      database.inTransaction(() async {
        final existing = await (database.select(database.durableInboxOperations)
              ..where((table) =>
                  table.sourceAuthority.equals(envelope.sourceAuthority) &
                  table.sourceOperationId
                      .equals(envelope.sourceOperationId.value)))
            .getSingleOrNull();
        if (existing != null) {
          if (!_sameInboxEnvelope(existing, envelope)) {
            throw const DurableIdentityConflictException(
              'inboundIdentityMismatch',
            );
          }
          return _inbox(existing);
        }
        final now = _now();
        await database.into(database.durableInboxOperations).insert(
              db.DurableInboxOperationsCompanion.insert(
                sourceAuthority: envelope.sourceAuthority,
                sourceOperationId: envelope.sourceOperationId.value,
                businessId: envelope.scope.businessId.value,
                scopeKind: envelope.scope.kind.name,
                warehouseId: Value(envelope.scope.warehouseId?.value),
                operationKind: envelope.operationKind,
                aggregateType: envelope.aggregateType,
                aggregateId: Value(envelope.aggregateId),
                payloadSchemaVersion: envelope.payloadSchemaVersion,
                payloadJson: envelope.payloadJson,
                payloadFingerprint: envelope.payloadFingerprint,
                sourceActorAuthUserId:
                    Value(envelope.sourceActorAuthUserId?.value),
                sourceDeviceId: Value(envelope.sourceDeviceId?.value),
                remoteEntityVersion: Value(envelope.remoteEntityVersion?.value),
                isDeleted: Value(envelope.deletionMetadata != null),
                deletionMetadataJson: Value(envelope.deletionMetadata == null
                    ? null
                    : canonicalJson(envelope.deletionMetadata!.toJson())),
                serverOccurredAtUtc: envelope.serverOccurredAtUtc,
                receivedAtUtc: now,
                state: DurableInboxState.received.name,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        return (await loadInbox(
          envelope.scope,
          envelope.sourceAuthority,
          envelope.sourceOperationId.value,
        ))!;
      });

  @override
  Future<DurableInboxOperation?> loadInbox(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId,
  ) async {
    final row = await (database.select(database.durableInboxOperations)
          ..where((table) =>
              table.sourceAuthority.equals(sourceAuthority) &
              table.sourceOperationId.equals(sourceOperationId) &
              _inboxScope(table, scope)))
        .getSingleOrNull();
    return row == null ? null : _inbox(row);
  }

  @override
  Future<DurableInboxOperation?> claimNextInbox(
    DurableScope scope, {
    required DateTime nowUtc,
    required Duration leaseDuration,
  }) =>
      database.inTransaction(() async {
        requireUtcInstant(nowUtc, 'nowUtc');
        if (leaseDuration <= Duration.zero) {
          throw ArgumentError.value(leaseDuration, 'leaseDuration');
        }
        final row = await (database.select(database.durableInboxOperations)
              ..where((table) =>
                  _inboxScope(table, scope) &
                  table.state.equals(DurableInboxState.received.name))
              ..orderBy([
                (table) => OrderingTerm.asc(table.receivedAtUtc),
                (table) => OrderingTerm.asc(table.sourceOperationId),
              ])
              ..limit(1))
            .getSingleOrNull();
        if (row == null) return null;
        final token = const Uuid().v4();
        final affected = await (database.update(database.durableInboxOperations)
              ..where((table) =>
                  table.sourceAuthority.equals(row.sourceAuthority) &
                  table.sourceOperationId.equals(row.sourceOperationId) &
                  _inboxScope(table, scope) &
                  table.state.equals(DurableInboxState.received.name) &
                  table.recordVersion.equals(row.recordVersion)))
            .write(
          db.DurableInboxOperationsCompanion(
            state: Value(DurableInboxState.applying.name),
            applyAttemptCount: Value(row.applyAttemptCount + 1),
            lastApplyAttemptAtUtc: Value(nowUtc),
            claimToken: Value(token),
            leaseExpiresAtUtc: Value(nowUtc.add(leaseDuration)),
            lastErrorClass: const Value(null),
            lastErrorCode: const Value(null),
            updatedAtUtc: Value(nowUtc),
            recordVersion: Value(row.recordVersion + 1),
          ),
        );
        if (affected != 1) return null;
        return loadInbox(scope, row.sourceAuthority, row.sourceOperationId);
      });

  @override
  Future<T> applyInbound<T>(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required Future<T> Function(DurableInboxEnvelope envelope) mutation,
    DurableCheckpoint? checkpoint,
  }) =>
      database.inTransaction(() async {
        final row = await _requiredApplying(
          scope,
          sourceAuthority,
          sourceOperationId,
          expectedRecordVersion,
          claimToken,
        );
        final result = await mutation(_inboxEnvelope(row));
        final now = _now();
        final affected = await (database.update(database.durableInboxOperations)
              ..where((table) =>
                  table.sourceAuthority.equals(sourceAuthority) &
                  table.sourceOperationId.equals(sourceOperationId) &
                  _inboxScope(table, scope) &
                  table.state.equals(DurableInboxState.applying.name) &
                  table.recordVersion.equals(expectedRecordVersion) &
                  table.claimToken.equals(claimToken)))
            .write(
          db.DurableInboxOperationsCompanion(
            state: Value(DurableInboxState.applied.name),
            claimToken: const Value(null),
            leaseExpiresAtUtc: const Value(null),
            appliedAtUtc: Value(now),
            updatedAtUtc: Value(now),
            recordVersion: Value(expectedRecordVersion + 1),
          ),
        );
        if (affected != 1) throw const DurableLostRaceException();
        if (checkpoint != null) {
          _requireCheckpointForInbox(checkpoint, scope, row);
          await _saveCheckpoint(checkpoint, now);
        }
        return result;
      });

  Future<void> retryInbox(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableErrorClass errorClass,
    required String errorCode,
  }) async {
    _stableCode(errorCode);
    final now = _now();
    final affected = await (database.update(database.durableInboxOperations)
          ..where((table) =>
              table.sourceAuthority.equals(sourceAuthority) &
              table.sourceOperationId.equals(sourceOperationId) &
              _inboxScope(table, scope) &
              table.state.equals(DurableInboxState.applying.name) &
              table.recordVersion.equals(expectedRecordVersion) &
              table.claimToken.equals(claimToken) &
              table.leaseExpiresAtUtc.isBiggerThanValue(now)))
        .write(
      db.DurableInboxOperationsCompanion(
        state: Value(DurableInboxState.received.name),
        claimToken: const Value(null),
        leaseExpiresAtUtc: const Value(null),
        lastErrorClass: Value(errorClass.name),
        lastErrorCode: Value(errorCode),
        updatedAtUtc: Value(now),
        recordVersion: Value(expectedRecordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  @override
  Future<int> recoverExpiredInboxClaims(DateTime nowUtc) {
    requireUtcInstant(nowUtc, 'nowUtc');
    return database.customUpdate(
      'UPDATE durable_inbox_operations SET state = ?, last_error_class = ?, '
      'last_error_code = ?, claim_token = NULL, lease_expires_at_utc = NULL, '
      'updated_at_utc = ?, record_version = record_version + 1 '
      'WHERE state = ? AND lease_expires_at_utc <= ?',
      variables: <Variable<Object>>[
        Variable<String>(DurableInboxState.received.name),
        Variable<String>(DurableErrorClass.staleClaimRecovered.name),
        const Variable<String>('staleClaimRecovered'),
        Variable<DateTime>(nowUtc),
        Variable<String>(DurableInboxState.applying.name),
        Variable<DateTime>(nowUtc),
      ],
      updates: {database.durableInboxOperations},
    );
  }

  @override
  Future<DurableConflict> recordConflict(
    DurableConflictEvidence evidence,
  ) =>
      database.inTransaction(() => _recordConflict(evidence));

  Future<DurableConflict> _recordConflict(
    DurableConflictEvidence evidence,
  ) async {
    final existing = await (database.select(database.durableConflicts)
          ..where((table) => table.conflictKey.equals(evidence.conflictKey)))
        .getSingleOrNull();
    if (existing != null) return _conflict(existing);
    final now = _now();
    await database.into(database.durableConflicts).insert(
          db.DurableConflictsCompanion.insert(
            conflictId: evidence.conflictId,
            conflictKey: evidence.conflictKey,
            businessId: evidence.scope.businessId.value,
            scopeKind: evidence.scope.kind.name,
            warehouseId: Value(evidence.scope.warehouseId?.value),
            entityType: evidence.entityType,
            entityId: evidence.entityId,
            localEntityVersion: Value(evidence.localEntityVersion?.value),
            remoteEntityVersion: Value(evidence.remoteEntityVersion?.value),
            localPayloadJson: evidence.localPayloadJson,
            remotePayloadJson: evidence.remotePayloadJson,
            localPayloadFingerprint: evidence.localPayloadFingerprint,
            remotePayloadFingerprint: evidence.remotePayloadFingerprint,
            localOperationId: Value(evidence.localOperationId?.value),
            remoteOperationId: Value(evidence.remoteOperationId?.value),
            remoteSourceAuthority: Value(evidence.remoteSourceAuthority),
            localDeleted: Value(evidence.localDeleted),
            remoteDeleted: Value(evidence.remoteDeleted),
            localDeletionMetadataJson: Value(
                evidence.localDeletionMetadata == null
                    ? null
                    : canonicalJson(evidence.localDeletionMetadata!.toJson())),
            remoteDeletionMetadataJson: Value(
                evidence.remoteDeletionMetadata == null
                    ? null
                    : canonicalJson(evidence.remoteDeletionMetadata!.toJson())),
            classification: evidence.classification.name,
            detectedAtUtc: evidence.detectedAtUtc,
            resolutionState: DurableConflictResolutionState.unresolved.name,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
    return (await loadConflict(evidence.conflictId))!;
  }

  @override
  Future<DurableConflict?> loadConflict(String conflictId) async {
    final row = await (database.select(database.durableConflicts)
          ..where((table) => table.conflictId.equals(conflictId)))
        .getSingleOrNull();
    return row == null ? null : _conflict(row);
  }

  @override
  Future<List<DurableConflict>> listUnresolvedConflicts(
    DurableScope scope,
  ) async {
    final rows = await (database.select(database.durableConflicts)
          ..where((table) =>
              _conflictScope(table, scope) &
              table.resolutionState
                  .equals(DurableConflictResolutionState.unresolved.name))
          ..orderBy([
            (table) => OrderingTerm.asc(table.detectedAtUtc),
            (table) => OrderingTerm.asc(table.conflictId),
          ]))
        .get();
    return List.unmodifiable(rows.map(_conflict));
  }

  @override
  Future<DurableConflict> conflictOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required DurableConflictEvidence evidence,
  }) =>
      database.inTransaction(() async {
        if (!scope.sameAs(evidence.scope)) {
          throw const DurableIdentityConflictException('scopeMismatch');
        }
        final conflict = await _recordConflict(evidence);
        final affected =
            await (database.update(database.durableOutboxOperations)
                  ..where((table) =>
                      table.operationId.equals(operationId) &
                      _outboxScope(table, scope) &
                      table.recordVersion.equals(expectedRecordVersion) &
                      table.state.isIn(<String>[
                        DurableOutboxState.claimed.name,
                        DurableOutboxState.acknowledgedPendingApply.name,
                      ])))
                .write(
          db.DurableOutboxOperationsCompanion(
            state: Value(DurableOutboxState.conflict.name),
            conflictId: Value(conflict.evidence.conflictId),
            claimToken: const Value(null),
            leaseExpiresAtUtc: const Value(null),
            lastErrorClass:
                Value(DurableErrorClass.reconciliationMismatch.name),
            lastErrorCode: const Value('durableConflict'),
            updatedAtUtc: Value(_now()),
            recordVersion: Value(expectedRecordVersion + 1),
          ),
        );
        if (affected != 1) throw const DurableLostRaceException();
        return conflict;
      });

  @override
  Future<DurableConflict> conflictInbox(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableConflictEvidence evidence,
    DurableCheckpoint? checkpoint,
  }) =>
      database.inTransaction(() async {
        if (!scope.sameAs(evidence.scope)) {
          throw const DurableIdentityConflictException('scopeMismatch');
        }
        final row = await _requiredApplying(
          scope,
          sourceAuthority,
          sourceOperationId,
          expectedRecordVersion,
          claimToken,
        );
        final conflict = await _recordConflict(evidence);
        final now = _now();
        final affected = await (database.update(database.durableInboxOperations)
              ..where((table) =>
                  table.sourceAuthority.equals(sourceAuthority) &
                  table.sourceOperationId.equals(sourceOperationId) &
                  _inboxScope(table, scope) &
                  table.state.equals(DurableInboxState.applying.name) &
                  table.recordVersion.equals(expectedRecordVersion) &
                  table.claimToken.equals(claimToken)))
            .write(
          db.DurableInboxOperationsCompanion(
            state: Value(DurableInboxState.conflict.name),
            conflictId: Value(conflict.evidence.conflictId),
            claimToken: const Value(null),
            leaseExpiresAtUtc: const Value(null),
            lastErrorClass: Value(DurableErrorClass.remoteConflict.name),
            lastErrorCode: const Value('durableConflict'),
            updatedAtUtc: Value(now),
            recordVersion: Value(expectedRecordVersion + 1),
          ),
        );
        if (affected != 1) throw const DurableLostRaceException();
        if (checkpoint != null) {
          _requireCheckpointForInbox(checkpoint, scope, row);
          await _saveCheckpoint(checkpoint, now);
        }
        return conflict;
      });

  @override
  Future<DurableCheckpoint?> loadCheckpoint(
    DurableScope scope,
    String sourceAuthority,
    String streamName,
  ) async {
    final row = await (database.select(database.durableSyncCheckpoints)
          ..where((table) =>
              _checkpointScope(table, scope) &
              table.sourceAuthority.equals(sourceAuthority) &
              table.streamName.equals(streamName)))
        .getSingleOrNull();
    return row == null ? null : _checkpoint(row);
  }

  Future<void> _saveCheckpoint(
    DurableCheckpoint checkpoint,
    DateTime now,
  ) async {
    if (checkpoint.sourceAuthority.trim().isEmpty ||
        checkpoint.streamName.trim().isEmpty ||
        checkpoint.cursorValue.isEmpty) {
      throw ArgumentError('Checkpoint identity and cursor are required.');
    }
    final existing = await (database.select(database.durableSyncCheckpoints)
          ..where((table) =>
              _checkpointScope(table, checkpoint.scope) &
              table.sourceAuthority.equals(checkpoint.sourceAuthority) &
              table.streamName.equals(checkpoint.streamName)))
        .getSingleOrNull();
    if (existing == null) {
      await database.into(database.durableSyncCheckpoints).insert(
            db.DurableSyncCheckpointsCompanion.insert(
              businessId: checkpoint.scope.businessId.value,
              scopeKind: checkpoint.scope.kind.name,
              warehouseId: Value(checkpoint.scope.warehouseId?.value),
              sourceAuthority: checkpoint.sourceAuthority,
              streamName: checkpoint.streamName,
              cursorValue: checkpoint.cursorValue,
              lastSourceOperationId:
                  Value(checkpoint.lastSourceOperationId?.value),
              updatedAtUtc: now,
            ),
          );
      return;
    }
    final affected = await (database.update(database.durableSyncCheckpoints)
          ..where((table) =>
              _checkpointScope(table, checkpoint.scope) &
              table.sourceAuthority.equals(checkpoint.sourceAuthority) &
              table.streamName.equals(checkpoint.streamName) &
              table.recordVersion.equals(existing.recordVersion)))
        .write(
      db.DurableSyncCheckpointsCompanion(
        cursorValue: Value(checkpoint.cursorValue),
        lastSourceOperationId: Value(checkpoint.lastSourceOperationId?.value),
        updatedAtUtc: Value(now),
        recordVersion: Value(existing.recordVersion + 1),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  void _requireCheckpointForInbox(
    DurableCheckpoint checkpoint,
    DurableScope scope,
    db.DurableInboxOperationRow row,
  ) {
    if (!checkpoint.scope.sameAs(scope) ||
        checkpoint.sourceAuthority != row.sourceAuthority ||
        checkpoint.lastSourceOperationId?.value != row.sourceOperationId) {
      throw const DurableIdentityConflictException('checkpointScopeMismatch');
    }
  }

  Future<db.DurableInboxOperationRow> _requiredApplying(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId,
    int expectedRecordVersion,
    String claimToken,
  ) async {
    final row = await (database.select(database.durableInboxOperations)
          ..where((table) =>
              table.sourceAuthority.equals(sourceAuthority) &
              table.sourceOperationId.equals(sourceOperationId) &
              _inboxScope(table, scope) &
              table.state.equals(DurableInboxState.applying.name) &
              table.recordVersion.equals(expectedRecordVersion) &
              table.claimToken.equals(claimToken)))
        .getSingleOrNull();
    if (row == null || !row.leaseExpiresAtUtc!.isAfter(_now())) {
      throw const DurableLostRaceException();
    }
    return row;
  }

  Expression<bool> _outboxScope(
    db.DurableOutboxOperations table,
    DurableScope scope,
  ) =>
      table.businessId.equals(scope.businessId.value) &
      table.scopeKind.equals(scope.kind.name) &
      (scope.warehouseId == null
          ? table.warehouseId.isNull()
          : table.warehouseId.equals(scope.warehouseId!.value));

  Expression<bool> _inboxScope(
    db.DurableInboxOperations table,
    DurableScope scope,
  ) =>
      table.businessId.equals(scope.businessId.value) &
      table.scopeKind.equals(scope.kind.name) &
      (scope.warehouseId == null
          ? table.warehouseId.isNull()
          : table.warehouseId.equals(scope.warehouseId!.value));

  Expression<bool> _conflictScope(
    db.DurableConflicts table,
    DurableScope scope,
  ) =>
      table.businessId.equals(scope.businessId.value) &
      table.scopeKind.equals(scope.kind.name) &
      (scope.warehouseId == null
          ? table.warehouseId.isNull()
          : table.warehouseId.equals(scope.warehouseId!.value));

  Expression<bool> _checkpointScope(
    db.DurableSyncCheckpoints table,
    DurableScope scope,
  ) =>
      table.businessId.equals(scope.businessId.value) &
      table.scopeKind.equals(scope.kind.name) &
      (scope.warehouseId == null
          ? table.warehouseId.isNull()
          : table.warehouseId.equals(scope.warehouseId!.value));

  bool _sameOutboxEnvelope(
    db.DurableOutboxOperationRow row,
    DurableOutboxEnvelope value,
  ) =>
      row.operationId == value.operationId.value &&
      row.idempotencyKey == value.idempotencyKey &&
      row.businessId == value.scope.businessId.value &&
      row.scopeKind == value.scope.kind.name &&
      row.warehouseId == value.scope.warehouseId?.value &&
      row.actorAuthUserId == value.actorAuthUserId.value &&
      row.deviceId == value.deviceId.value &&
      row.sessionId == value.sessionId.value &&
      row.capturedRole == value.capturedRole &&
      row.operationKind == value.operationKind &&
      row.aggregateType == value.aggregateType &&
      row.aggregateId == value.aggregateId &&
      row.payloadSchemaVersion == value.payloadSchemaVersion &&
      row.payloadJson == value.payloadJson &&
      row.payloadFingerprint == value.payloadFingerprint &&
      row.baseEntityVersion == value.baseEntityVersion?.value &&
      row.isDeletionIntent == value.isDeletionIntent &&
      row.occurredAtUtc.toUtc() == value.occurredAtUtc &&
      row.businessDate == value.businessDate?.value &&
      row.causalPredecessorOperationId ==
          value.causalPredecessorOperationId?.value;

  bool _sameInboxEnvelope(
    db.DurableInboxOperationRow row,
    DurableInboxEnvelope value,
  ) =>
      row.sourceAuthority == value.sourceAuthority &&
      row.sourceOperationId == value.sourceOperationId.value &&
      row.businessId == value.scope.businessId.value &&
      row.scopeKind == value.scope.kind.name &&
      row.warehouseId == value.scope.warehouseId?.value &&
      row.operationKind == value.operationKind &&
      row.aggregateType == value.aggregateType &&
      row.aggregateId == value.aggregateId &&
      row.payloadSchemaVersion == value.payloadSchemaVersion &&
      row.payloadJson == value.payloadJson &&
      row.payloadFingerprint == value.payloadFingerprint &&
      row.sourceActorAuthUserId == value.sourceActorAuthUserId?.value &&
      row.sourceDeviceId == value.sourceDeviceId?.value &&
      row.remoteEntityVersion == value.remoteEntityVersion?.value &&
      row.isDeleted == (value.deletionMetadata != null) &&
      row.deletionMetadataJson ==
          (value.deletionMetadata == null
              ? null
              : canonicalJson(value.deletionMetadata!.toJson())) &&
      row.serverOccurredAtUtc.toUtc() == value.serverOccurredAtUtc;

  DurableOutboxOperation _outbox(db.DurableOutboxOperationRow row) {
    final scope = _scope(row.businessId, row.scopeKind, row.warehouseId);
    return DurableOutboxOperation(
      envelope: DurableOutboxEnvelope(
        operationId: OperationId(row.operationId),
        idempotencyKey: row.idempotencyKey,
        scope: scope,
        actorAuthUserId: RemoteAuthUserId(row.actorAuthUserId),
        deviceId: DeviceId(row.deviceId),
        sessionId: SessionId(row.sessionId),
        capturedRole: row.capturedRole,
        operationKind: row.operationKind,
        aggregateType: row.aggregateType,
        aggregateId: row.aggregateId,
        payloadSchemaVersion: row.payloadSchemaVersion,
        payloadJson: row.payloadJson,
        payloadFingerprint: row.payloadFingerprint,
        baseEntityVersion: row.baseEntityVersion == null
            ? null
            : EntityVersion(row.baseEntityVersion!),
        isDeletionIntent: row.isDeletionIntent,
        occurredAtUtc: row.occurredAtUtc.toUtc(),
        businessDate:
            row.businessDate == null ? null : BusinessDate(row.businessDate!),
        causalPredecessorOperationId: row.causalPredecessorOperationId == null
            ? null
            : OperationId(row.causalPredecessorOperationId!),
      ),
      state: DurableOutboxState.values.byName(row.state),
      attemptCount: row.attemptCount,
      nextAttemptAtUtc: row.nextAttemptAtUtc?.toUtc(),
      lastAttemptAtUtc: row.lastAttemptAtUtc?.toUtc(),
      lastErrorClass: row.lastErrorClass == null
          ? null
          : DurableErrorClass.values.byName(row.lastErrorClass!),
      lastErrorCode: row.lastErrorCode,
      claimToken: row.claimToken,
      leaseExpiresAtUtc: row.leaseExpiresAtUtc?.toUtc(),
      acknowledgement: row.ackPayloadJson == null
          ? null
          : DurableAcknowledgement(
              schemaVersion: row.ackSchemaVersion!,
              payloadJson: row.ackPayloadJson!,
              payloadFingerprint: row.ackPayloadFingerprint!,
              serverResultId: row.serverResultId,
              serverAcceptedAtUtc: row.serverAcceptedAtUtc!.toUtc(),
              acknowledgedEntityVersion: row.acknowledgedEntityVersion == null
                  ? null
                  : EntityVersion(row.acknowledgedEntityVersion!),
            ),
      conflictId: row.conflictId,
      createdAtUtc: row.createdAtUtc.toUtc(),
      updatedAtUtc: row.updatedAtUtc.toUtc(),
      recordVersion: row.recordVersion,
    );
  }

  DurableInboxOperation _inbox(db.DurableInboxOperationRow row) =>
      DurableInboxOperation(
        envelope: _inboxEnvelope(row),
        state: DurableInboxState.values.byName(row.state),
        applyAttemptCount: row.applyAttemptCount,
        receivedAtUtc: row.receivedAtUtc.toUtc(),
        lastApplyAttemptAtUtc: row.lastApplyAttemptAtUtc?.toUtc(),
        lastErrorClass: row.lastErrorClass == null
            ? null
            : DurableErrorClass.values.byName(row.lastErrorClass!),
        lastErrorCode: row.lastErrorCode,
        claimToken: row.claimToken,
        leaseExpiresAtUtc: row.leaseExpiresAtUtc?.toUtc(),
        appliedAtUtc: row.appliedAtUtc?.toUtc(),
        rejectedAtUtc: row.rejectedAtUtc?.toUtc(),
        conflictId: row.conflictId,
        createdAtUtc: row.createdAtUtc.toUtc(),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
        recordVersion: row.recordVersion,
      );

  DurableInboxEnvelope _inboxEnvelope(db.DurableInboxOperationRow row) =>
      DurableInboxEnvelope(
        sourceAuthority: row.sourceAuthority,
        sourceOperationId: OperationId(row.sourceOperationId),
        scope: _scope(row.businessId, row.scopeKind, row.warehouseId),
        operationKind: row.operationKind,
        aggregateType: row.aggregateType,
        aggregateId: row.aggregateId,
        payloadSchemaVersion: row.payloadSchemaVersion,
        payloadJson: row.payloadJson,
        payloadFingerprint: row.payloadFingerprint,
        sourceActorAuthUserId: row.sourceActorAuthUserId == null
            ? null
            : RemoteAuthUserId(row.sourceActorAuthUserId!),
        sourceDeviceId:
            row.sourceDeviceId == null ? null : DeviceId(row.sourceDeviceId!),
        remoteEntityVersion: row.remoteEntityVersion == null
            ? null
            : EntityVersion(row.remoteEntityVersion!),
        deletionMetadata: _deletion(row.deletionMetadataJson),
        serverOccurredAtUtc: row.serverOccurredAtUtc.toUtc(),
      );

  DurableConflict _conflict(db.DurableConflictRow row) => DurableConflict(
        evidence: DurableConflictEvidence(
          conflictId: row.conflictId,
          scope: _scope(row.businessId, row.scopeKind, row.warehouseId),
          entityType: row.entityType,
          entityId: row.entityId,
          localEntityVersion: row.localEntityVersion == null
              ? null
              : EntityVersion(row.localEntityVersion!),
          remoteEntityVersion: row.remoteEntityVersion == null
              ? null
              : EntityVersion(row.remoteEntityVersion!),
          localPayloadJson: row.localPayloadJson,
          remotePayloadJson: row.remotePayloadJson,
          localOperationId: row.localOperationId == null
              ? null
              : OperationId(row.localOperationId!),
          remoteOperationId: row.remoteOperationId == null
              ? null
              : OperationId(row.remoteOperationId!),
          remoteSourceAuthority: row.remoteSourceAuthority,
          localDeletionMetadata: _deletion(row.localDeletionMetadataJson),
          remoteDeletionMetadata: _deletion(row.remoteDeletionMetadataJson),
          classification:
              DurableConflictClassification.values.byName(row.classification),
          detectedAtUtc: row.detectedAtUtc.toUtc(),
        ),
        resolutionState:
            DurableConflictResolutionState.values.byName(row.resolutionState),
        createdAtUtc: row.createdAtUtc.toUtc(),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
        recordVersion: row.recordVersion,
      );

  DurableCheckpoint _checkpoint(db.DurableSyncCheckpointRow row) =>
      DurableCheckpoint(
        scope: _scope(row.businessId, row.scopeKind, row.warehouseId),
        sourceAuthority: row.sourceAuthority,
        streamName: row.streamName,
        cursorValue: row.cursorValue,
        lastSourceOperationId: row.lastSourceOperationId == null
            ? null
            : OperationId(row.lastSourceOperationId!),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
        recordVersion: row.recordVersion,
      );

  DurableScope _scope(String businessId, String kind, String? warehouseId) =>
      DurableScope(
        businessId: BusinessId(businessId),
        kind: DurableScopeKind.values.byName(kind),
        warehouseId: warehouseId == null ? null : WarehouseId(warehouseId),
      );

  DeletionMetadata? _deletion(String? value) {
    if (value == null) return null;
    final json = (jsonDecode(value) as Map).cast<String, Object?>();
    return DeletionMetadata(
      deletionVersion: EntityVersion(json['deletionVersion']! as int),
      deletedAtUtc: DateTime.parse(json['deletedAtUtc']! as String).toUtc(),
      deletedByAuthUserId:
          RemoteAuthUserId(json['deletedByAuthUserId']! as String),
      deletedByDeviceId: DeviceId(json['deletedByDeviceId']! as String),
      sourceOperationId: OperationId(json['sourceOperationId']! as String),
    );
  }

  void _stableCode(String value) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'errorCode', 'Stable code required.');
    }
  }
}
