import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:uuid/uuid.dart';

final class DriftExpensePostingAttemptStore
    implements ExpensePostingAttemptStore, FinancialAccountCloudLinkResolver {
  DriftExpensePostingAttemptStore(
    this._database, {
    required FinancialAccountRepository financialAccountRepository,
  }) : _financialAccountRepository = financialAccountRepository;

  final db.FoundationDatabase _database;
  final FinancialAccountRepository _financialAccountRepository;

  @override
  Future<ExpensePostingAttempt> prepare({
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
            throw const ExpensePostingAttemptConflictException();
          }
          return existing;
        }
        final now = DateTime.now().toUtc();
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
    final row = await (_database.select(_database.expensePostingAttempts)
          ..where((table) => table.commandId.equals(commandId)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> markSending(String commandId) async {
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
  ) =>
      _update(
        commandId,
        state: ExpensePostingAttemptState.confirmedProjectionPending,
        canonicalServerResultJson: canonicalServerResultJson,
        clearError: true,
      );

  @override
  Future<void> markConfirmed(String commandId) => _update(
        commandId,
        state: ExpensePostingAttemptState.confirmed,
        clearError: true,
      );

  @override
  Future<void> markFailure(
    String commandId, {
    required ExpensePostingAttemptState state,
    required String errorCode,
  }) =>
      _update(commandId, state: state, lastErrorCode: errorCode);

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
