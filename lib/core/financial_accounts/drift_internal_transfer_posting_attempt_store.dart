import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

final class DriftInternalTransferPostingAttemptStore
    implements InternalTransferPostingAttemptStore {
  DriftInternalTransferPostingAttemptStore(this._database);

  final db.FoundationDatabase _database;

  @override
  Future<InternalTransferPostingAttempt> prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
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
        final now = DateTime.now().toUtc();
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
        return (await load(commandId))!;
      });

  @override
  Future<InternalTransferPostingAttempt?> load(String commandId) async {
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
    final rows =
        await (_database.select(_database.internalTransferPostingAttempts)
              ..where((table) =>
                  table.businessId.equals(businessId) &
                  table.lifecycleState.isNotIn(<String>[
                    InternalTransferPostingAttemptState.confirmed.name,
                    InternalTransferPostingAttemptState.rejected.name,
                  ]))
              ..orderBy([
                (table) => OrderingTerm.desc(table.updatedAtUtc),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> markSending(String commandId) async {
    final current = await _required(commandId);
    await _update(
      commandId,
      state: InternalTransferPostingAttemptState.sending,
      attemptCount: current.attemptCount + 1,
      clearError: true,
    );
  }

  @override
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  ) =>
      _update(
        commandId,
        state: InternalTransferPostingAttemptState.confirmedProjectionPending,
        canonicalServerResultJson: canonicalServerResultJson,
        clearError: true,
      );

  @override
  Future<void> markConfirmed(String commandId) => _update(
        commandId,
        state: InternalTransferPostingAttemptState.confirmed,
        clearError: true,
      );

  @override
  Future<void> markFailure(
    String commandId, {
    required InternalTransferPostingAttemptState state,
    required String errorCode,
  }) =>
      _update(commandId, state: state, lastErrorCode: errorCode);

  Future<void> _update(
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
            .write(
      db.InternalTransferPostingAttemptsCompanion(
        lifecycleState: Value(state.name),
        canonicalServerResultJson: canonicalServerResultJson == null
            ? const Value.absent()
            : Value(canonicalServerResultJson),
        updatedAtUtc: Value(DateTime.now().toUtc()),
        attemptCount:
            attemptCount == null ? const Value.absent() : Value(attemptCount),
        lastErrorCode: clearError
            ? const Value(null)
            : lastErrorCode == null
                ? const Value.absent()
                : Value(lastErrorCode),
      ),
    );
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
