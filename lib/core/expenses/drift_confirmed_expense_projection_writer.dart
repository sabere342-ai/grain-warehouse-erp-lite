import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

enum ConfirmedExpenseProjectionStage {
  afterExpense,
  afterEntry,
  afterAudits,
}

final class DriftConfirmedExpenseProjectionWriter
    implements ConfirmedExpenseProjectionWriter {
  DriftConfirmedExpenseProjectionWriter(
    this._database, {
    required DriftFinancialAccountRepository financialAccountRepository,
    FutureOr<void> Function(ConfirmedExpenseProjectionStage stage)?
        failureInjector,
  })  : _financialAccountRepository = financialAccountRepository,
        _failureInjector = failureInjector;

  final db.FoundationDatabase _database;
  final DriftFinancialAccountRepository _financialAccountRepository;
  final FutureOr<void> Function(ConfirmedExpenseProjectionStage stage)?
      _failureInjector;

  @override
  Future<void> project(ConfirmedExpenseProjection value) async {
    if (value.auditEventIds.length != 2 ||
        value.auditEventIds[0] == value.auditEventIds[1]) {
      throw StateError(
          'Exactly two distinct authoritative audit IDs required.');
    }
    await _financialAccountRepository.applySerializedExternalProjection(
      () => _database.inTransaction(() => _projectTransaction(value)),
    );
  }

  Future<void> _projectTransaction(ConfirmedExpenseProjection value) async {
    final link = await (_database.select(_database.financialAccountCloudLinks)
          ..where((table) =>
              table.businessId.equals(value.businessId) &
              table.serverAccountUuid.equals(value.serverAccountId)))
        .getSingleOrNull();
    if (link == null) throw StateError('Cloud-ready account link is missing.');

    final existingByCommand = await (_database.select(_database.expenses)
          ..where((table) => table.operationRequestId.equals(value.commandId)))
        .getSingleOrNull();
    if (existingByCommand != null && existingByCommand.id != value.expenseId) {
      throw StateError('Projected command conflicts with an existing expense.');
    }
    final existingExpense = await (_database.select(_database.expenses)
          ..where((table) => table.id.equals(value.expenseId)))
        .getSingleOrNull();
    if (existingExpense == null) {
      await _database.into(_database.expenses).insert(
            db.ExpensesCompanion.insert(
              id: value.expenseId,
              date: _date(value.businessDate),
              category: value.category,
              amountQirsh: value.amountQirsh,
              notes: Value(value.notes),
              createdAt: value.serverAcceptedAtUtc.microsecondsSinceEpoch,
              financialAccountId: Value(link.localAccountId),
              paymentMethod: Value(value.paymentMethod.name),
              createdByUserId: Value(value.actorAuthUserId),
              operationRequestId: Value(value.commandId),
              operationRequestFingerprint: Value(value.localFingerprint),
              accountingClassification:
                  Value(value.accountingClassification.name),
            ),
          );
    } else {
      _require(existingExpense.operationRequestId == value.commandId &&
          existingExpense.operationRequestFingerprint ==
              value.localFingerprint &&
          existingExpense.date == _date(value.businessDate) &&
          existingExpense.category == value.category &&
          existingExpense.amountQirsh == value.amountQirsh &&
          existingExpense.notes == value.notes &&
          existingExpense.financialAccountId == link.localAccountId &&
          existingExpense.paymentMethod == value.paymentMethod.name &&
          existingExpense.createdAt ==
              value.serverAcceptedAtUtc.microsecondsSinceEpoch &&
          existingExpense.createdByUserId == value.actorAuthUserId &&
          existingExpense.accountingClassification ==
              value.accountingClassification.name);
    }
    await _failureInjector?.call(ConfirmedExpenseProjectionStage.afterExpense);

    final existingEntry =
        await (_database.select(_database.financialAccountEntries)
              ..where((table) => table.id.equals(value.financialEntryId)))
            .getSingleOrNull();
    if (existingEntry == null) {
      await _database.into(_database.financialAccountEntries).insert(
            db.FinancialAccountEntriesCompanion.insert(
              id: value.financialEntryId,
              accountId: link.localAccountId,
              direction: 'outflow',
              amountQirsh: value.amountQirsh,
              sourceType: 'expense',
              sourceDocumentId: value.expenseId,
              effectiveDate: _date(value.businessDate),
              createdAt: value.serverAcceptedAtUtc,
              createdByUserId: value.actorAuthUserId,
              reference: Value('مصروف: ${value.category}'),
              note: Value(value.notes),
              paymentMethod: Value(value.paymentMethod.name),
            ),
          );
    } else {
      _require(existingEntry.accountId == link.localAccountId &&
          existingEntry.direction == 'outflow' &&
          existingEntry.amountQirsh == value.amountQirsh &&
          existingEntry.sourceType == 'expense' &&
          existingEntry.sourceDocumentId == value.expenseId &&
          existingEntry.effectiveDate == _date(value.businessDate) &&
          existingEntry.createdAt.millisecondsSinceEpoch ==
              value.serverAcceptedAtUtc.millisecondsSinceEpoch &&
          existingEntry.createdByUserId == value.actorAuthUserId &&
          existingEntry.reference == 'مصروف: ${value.category}' &&
          existingEntry.note == value.notes &&
          existingEntry.paymentMethod == value.paymentMethod.name);
    }
    await _failureInjector?.call(ConfirmedExpenseProjectionStage.afterEntry);

    await _projectAudit(
      id: value.auditEventIds[0],
      timestamp: value.serverAcceptedAtUtc,
      actionType: 'financial_account.entry.created',
      descriptionAr: 'تم اعتماد حركة مصروف على الحساب المالي من الخادم.',
      actorId: value.actorAuthUserId,
      referenceId: value.financialEntryId,
      value: value,
    );
    await _projectAudit(
      id: value.auditEventIds[1],
      timestamp: value.serverAcceptedAtUtc,
      actionType: 'expense.created',
      descriptionAr: 'تم اعتماد المصروف ${value.category} من الخادم.',
      actorId: value.actorAuthUserId,
      referenceId: value.expenseId,
      value: value,
    );
    await _failureInjector?.call(ConfirmedExpenseProjectionStage.afterAudits);

    final rows = await _database.customSelect(
      'SELECT COALESCE(SUM(CASE WHEN direction = ? THEN amount_qirsh '
      'ELSE -amount_qirsh END), 0) AS balance '
      'FROM financial_account_entries WHERE account_id = ?',
      variables: [
        const Variable<String>('inflow'),
        Variable<String>(link.localAccountId),
      ],
      readsFrom: {_database.financialAccountEntries},
    ).getSingle();
    final localBalance = rows.read<int>('balance');
    if (localBalance != value.balanceAfterQirsh) {
      throw StateError('Projected account balance does not match the server.');
    }
    await (_database.update(_database.financialAccountCloudLinks)
          ..where((table) => table.localAccountId.equals(link.localAccountId)))
        .write(
      db.FinancialAccountCloudLinksCompanion(
        reconciledServerBalanceQirsh: Value(value.balanceAfterQirsh),
        reconciledAtUtc: Value(value.serverAcceptedAtUtc),
        reconciliationVersion: Value(link.reconciliationVersion + 1),
      ),
    );
    await (_database.update(_database.expensePostingAttempts)
          ..where((table) => table.commandId.equals(value.commandId)))
        .write(
      db.ExpensePostingAttemptsCompanion(
        lifecycleState: Value(ExpensePostingAttemptState.confirmed.name),
        updatedAtUtc: Value(DateTime.now().toUtc()),
        lastErrorCode: const Value(null),
      ),
    );
  }

  Future<void> _projectAudit({
    required String id,
    required DateTime timestamp,
    required String actionType,
    required String descriptionAr,
    required String actorId,
    required String referenceId,
    required ConfirmedExpenseProjection value,
  }) async {
    final existing = await (_database.select(_database.auditLogs)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) {
      _require(existing.actionType == actionType &&
          existing.referenceId == referenceId &&
          existing.timestamp.millisecondsSinceEpoch ==
              timestamp.millisecondsSinceEpoch &&
          existing.actorId == actorId &&
          existing.metadataJson == _auditMetadata(value));
      return;
    }
    await _database.into(_database.auditLogs).insert(
          db.AuditLogsCompanion.insert(
            id: id,
            timestamp: timestamp,
            actionType: actionType,
            descriptionAr: descriptionAr,
            actorId: Value(actorId),
            referenceId: Value(referenceId),
            metadataJson: _auditMetadata(value),
          ),
        );
  }

  String _auditMetadata(ConfirmedExpenseProjection value) =>
      jsonEncode(<String, Object?>{
        'businessId': value.businessId,
        'commandId': value.commandId,
        'expenseId': value.expenseId,
        'financialAccountId': value.serverAccountId,
        'serverAcceptedAtUtc': value.serverAcceptedAtUtc.toIso8601String(),
      });

  DateTime _date(String value) {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return DateTime(parts[0], parts[1], parts[2]);
  }

  void _require(bool condition) {
    if (!condition) throw StateError('Conflicting acknowledged projection.');
  }
}
