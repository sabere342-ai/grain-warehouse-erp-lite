import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:uuid/uuid.dart';

final class DriftExpensePostingAttemptStore
    implements
        DurableExpensePostingAttemptStore,
        FinancialAccountCloudLinkResolver {
  DriftExpensePostingAttemptStore(
    db.FoundationDatabase database, {
    required FinancialAccountRepository financialAccountRepository,
    ApplicationClock clock = const SystemApplicationClock(),
    DriftDurableSyncStore? durableSyncStore,
  })  : _database = database,
        _financialAccountRepository = financialAccountRepository,
        _clock = clock,
        _durableSyncStore =
            durableSyncStore ?? DriftDurableSyncStore(database, clock: clock);

  final db.FoundationDatabase _database;
  final FinancialAccountRepository _financialAccountRepository;
  final ApplicationClock _clock;
  final DriftDurableSyncStore _durableSyncStore;

  static const _operationKind = 'financial.expense.post.v1';

  @override
  Future<ExpensePostingAttempt> prepare({
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
  Future<ExpensePostingAttempt> prepareDurable({
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

  Future<ExpensePostingAttempt> _prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
    ExecutionContext? executionContext,
    BusinessDate? businessDate,
  }) =>
      _database.inTransaction(() async {
        final legacy = await _loadLegacy(commandId);
        if (legacy != null) {
          if (legacy.businessId != businessId ||
              legacy.canonicalPayloadJson != canonicalPayloadJson ||
              legacy.localFingerprint != localFingerprint) {
            throw const ExpensePostingAttemptConflictException();
          }
          return legacy;
        }
        final generic = await _generic(commandId);
        if (generic != null) {
          if (generic.businessId != businessId ||
              generic.canonicalPayloadJson != canonicalPayloadJson ||
              generic.localFingerprint != localFingerprint) {
            throw const ExpensePostingAttemptConflictException();
          }
          return generic;
        }
        if (executionContext != null && businessDate != null) {
          try {
            final now = requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc');
            final operation = await _durableSyncStore.enqueue(
              DurableOutboxEnvelope.fromExecutionContext(
                operationId: OperationId(commandId),
                idempotencyKey: commandId,
                context: executionContext,
                operationKind: _operationKind,
                aggregateType: 'expense',
                payloadSchemaVersion: 1,
                payloadJson: canonicalPayloadJson,
                payloadFingerprint: localFingerprint,
                occurredAtUtc: now,
                businessDate: businessDate,
              ),
            );
            return _genericDomain(operation);
          } on DurableIdentityConflictException {
            throw const ExpensePostingAttemptConflictException();
          }
        }
        final existing = await load(commandId);
        if (existing != null) {
          if (existing.businessId != businessId ||
              existing.canonicalPayloadJson != canonicalPayloadJson ||
              existing.localFingerprint != localFingerprint) {
            throw const ExpensePostingAttemptConflictException();
          }
          return existing;
        }
        final now = requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc');
        await _database.into(_database.expensePostingAttempts).insert(
              db.ExpensePostingAttemptsCompanion.insert(
                commandId: commandId,
                businessId: businessId,
                canonicalPayloadJson: canonicalPayloadJson,
                localFingerprint: localFingerprint,
                lifecycleState: ExpensePostingAttemptState.queued.name,
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        return (await load(commandId))!;
      });

  @override
  Future<ExpensePostingAttempt?> load(String commandId) async {
    final legacy = await _loadLegacy(commandId);
    if (legacy != null) return legacy;
    return _generic(commandId);
  }

  Future<ExpensePostingAttempt?> _loadLegacy(String commandId) async {
    final row = await (_database.select(_database.expensePostingAttempts)
          ..where((table) => table.commandId.equals(commandId)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
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
    await _update(
      commandId,
      state: ExpensePostingAttemptState.sending,
      attemptCount: current.attemptCount + 1,
      clearError: true,
    );
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
          throw const ExpensePostingAttemptConflictException();
        }
        return;
      }
      final accepted = _serverAcceptedAt(canonicalServerResultJson);
      await _durableSyncStore.acknowledgeOutbox(
        generic.envelope.scope,
        commandId,
        expectedRecordVersion: generic.recordVersion,
        claimToken: generic.claimToken!,
        acknowledgement: DurableAcknowledgement(
          schemaVersion: 1,
          payloadJson: canonicalServerResultJson,
          payloadFingerprint: payloadFingerprint(canonicalServerResultJson),
          serverAcceptedAtUtc: accepted,
        ),
      );
      return;
    }
    await _update(
      commandId,
      state: ExpensePostingAttemptState.confirmedProjectionPending,
      canonicalServerResultJson: canonicalServerResultJson,
      clearError: true,
    );
  }

  @override
  Future<void> markConfirmed(String commandId) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      if (generic.state == DurableOutboxState.completed) return;
      await _durableSyncStore.completeOutbox(
        generic.envelope.scope,
        commandId,
        expectedRecordVersion: generic.recordVersion,
      );
      return;
    }
    await _update(
      commandId,
      state: ExpensePostingAttemptState.confirmed,
      clearError: true,
    );
  }

  @override
  Future<void> markFailure(
    String commandId, {
    required ExpensePostingAttemptState state,
    required String errorCode,
  }) async {
    final generic = await _genericOperation(commandId);
    if (generic != null) {
      if (generic.state == DurableOutboxState.conflict) return;
      if (generic.state == DurableOutboxState.acknowledgedPendingApply &&
          state == ExpensePostingAttemptState.confirmedProjectionPending) {
        return;
      }
      if (generic.state != DurableOutboxState.claimed ||
          generic.claimToken == null) {
        throw const DurableLostRaceException();
      }
      if (state == ExpensePostingAttemptState.rejected) {
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
    await _update(commandId, state: state, lastErrorCode: errorCode);
  }

  Future<DurableOutboxOperation?> _genericOperation(String commandId) async {
    final operation = await _durableSyncStore
        .loadOutboxByOperationIdForCompatibility(commandId);
    return operation?.envelope.operationKind == _operationKind
        ? operation
        : null;
  }

  Future<ExpensePostingAttempt?> _generic(String commandId) async {
    final operation = await _genericOperation(commandId);
    return operation == null ? null : _genericDomain(operation);
  }

  ExpensePostingAttempt _genericDomain(DurableOutboxOperation operation) =>
      ExpensePostingAttempt(
        commandId: operation.envelope.operationId.value,
        businessId: operation.envelope.scope.businessId.value,
        canonicalPayloadJson: operation.envelope.payloadJson,
        localFingerprint: operation.envelope.payloadFingerprint,
        state: switch (operation.state) {
          DurableOutboxState.pending => ExpensePostingAttemptState.queued,
          DurableOutboxState.claimed => ExpensePostingAttemptState.sending,
          DurableOutboxState.retryWait =>
            ExpensePostingAttemptState.unknownOutcome,
          DurableOutboxState.acknowledgedPendingApply =>
            ExpensePostingAttemptState.confirmedProjectionPending,
          DurableOutboxState.completed => ExpensePostingAttemptState.confirmed,
          DurableOutboxState.permanentFailure ||
          DurableOutboxState.cancelled ||
          DurableOutboxState.conflict =>
            ExpensePostingAttemptState.rejected,
        },
        canonicalServerResultJson: operation.acknowledgement?.payloadJson,
        createdAtUtc: operation.createdAtUtc,
        updatedAtUtc: operation.updatedAtUtc,
        attemptCount: operation.attemptCount,
        lastErrorCode: operation.lastErrorCode,
      );

  DateTime _serverAcceptedAt(String payload) {
    final value = (jsonDecode(payload)
        as Map<String, dynamic>)['serverAcceptedAtUtc'] as String?;
    return value == null
        ? requireUtcInstant(_clock.nowUtc(), 'clock.nowUtc')
        : requireUtcInstant(
            DateTime.parse(value).toUtc(), 'serverAcceptedAtUtc');
  }

  Future<void> _update(
    String commandId, {
    required ExpensePostingAttemptState state,
    String? canonicalServerResultJson,
    int? attemptCount,
    String? lastErrorCode,
    bool clearError = false,
  }) async {
    final affected = await (_database.update(_database.expensePostingAttempts)
          ..where((table) => table.commandId.equals(commandId)))
        .write(
      db.ExpensePostingAttemptsCompanion(
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
      ),
    );
    if (affected != 1) throw StateError('Expense posting attempt is missing.');
  }

  Future<ExpensePostingAttempt> _required(String commandId) async {
    final value = await load(commandId);
    if (value == null) throw StateError('Expense posting attempt is missing.');
    return value;
  }

  @override
  Future<FinancialAccountCloudLink?> readyLinkForLocalAccount({
    required String localAccountId,
    required String businessId,
  }) async {
    final row = await (_database.select(_database.financialAccountCloudLinks)
          ..where((table) =>
              table.localAccountId.equals(localAccountId) &
              table.businessId.equals(businessId)))
        .getSingleOrNull();
    if (row == null) return null;
    if (!Uuid.isValidUUID(fromString: row.serverAccountUuid)) {
      return null;
    }
    try {
      final account =
          await _financialAccountRepository.accountById(localAccountId);
      if (!account.isActive) return null;
      final localBalance = await _financialAccountRepository
          .currentBalanceForAccount(localAccountId);
      if (localBalance != row.reconciledServerBalanceQirsh) return null;
      return _toLink(row);
    } on Object {
      return null;
    }
  }

  /// Controlled pilot setup seam. No production UI calls this method.
  Future<void> saveVerifiedCloudLink(FinancialAccountCloudLink link) async {
    final account = await _financialAccountRepository.accountById(
      link.localAccountId,
    );
    final balance = await _financialAccountRepository
        .currentBalanceForAccount(link.localAccountId);
    if (!account.isActive ||
        balance != link.reconciledServerBalanceQirsh ||
        !Uuid.isValidUUID(fromString: link.businessId) ||
        !Uuid.isValidUUID(fromString: link.serverAccountUuid) ||
        link.reconciliationVersion <= 0) {
      throw StateError('Cloud account reconciliation is not ready.');
    }
    final localConflict =
        await (_database.select(_database.financialAccountCloudLinks)
              ..where((table) => table.localAccountId.equals(
                    link.localAccountId,
                  )))
            .getSingleOrNull();
    if (localConflict != null &&
        (localConflict.businessId != link.businessId ||
            localConflict.serverAccountUuid != link.serverAccountUuid)) {
      throw StateError('Local account already has a different cloud link.');
    }
    final serverConflict =
        await (_database.select(_database.financialAccountCloudLinks)
              ..where((table) =>
                  table.businessId.equals(link.businessId) &
                  table.serverAccountUuid.equals(link.serverAccountUuid)))
            .getSingleOrNull();
    if (serverConflict != null &&
        serverConflict.localAccountId != link.localAccountId) {
      throw StateError('Server account already has a different local link.');
    }
    await _database.into(_database.financialAccountCloudLinks).insert(
          db.FinancialAccountCloudLinksCompanion.insert(
            localAccountId: link.localAccountId,
            businessId: link.businessId,
            serverAccountUuid: link.serverAccountUuid,
            reconciledServerBalanceQirsh: link.reconciledServerBalanceQirsh,
            reconciledAtUtc: link.reconciledAtUtc.toUtc(),
            reconciliationVersion: link.reconciliationVersion,
            readyAtUtc: link.readyAtUtc.toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  ExpensePostingAttempt _toDomain(db.ExpensePostingAttemptRow row) =>
      ExpensePostingAttempt(
        commandId: row.commandId,
        businessId: row.businessId,
        canonicalPayloadJson: row.canonicalPayloadJson,
        localFingerprint: row.localFingerprint,
        state: ExpensePostingAttemptState.values.byName(row.lifecycleState),
        canonicalServerResultJson: row.canonicalServerResultJson,
        createdAtUtc: row.createdAtUtc.toUtc(),
        updatedAtUtc: row.updatedAtUtc.toUtc(),
        attemptCount: row.attemptCount,
        lastErrorCode: row.lastErrorCode,
      );

  FinancialAccountCloudLink _toLink(db.FinancialAccountCloudLinkRow row) =>
      FinancialAccountCloudLink(
        localAccountId: row.localAccountId,
        businessId: row.businessId,
        serverAccountUuid: row.serverAccountUuid,
        reconciledServerBalanceQirsh: row.reconciledServerBalanceQirsh,
        reconciledAtUtc: row.reconciledAtUtc.toUtc(),
        reconciliationVersion: row.reconciliationVersion,
        readyAtUtc: row.readyAtUtc.toUtc(),
      );
}
