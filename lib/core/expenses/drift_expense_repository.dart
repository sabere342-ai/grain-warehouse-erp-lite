import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftExpenseRepository implements DurableExpenseRepository {
  DriftExpenseRepository(
    this._database, {
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
  })  : _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository;

  final db.FoundationDatabase _database;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  static const _sequenceKey = 'expenses';

  @override
  Future<List<ExpenseRecord>> listExpenses() async {
    final query = _database.select(_database.expenses)
      ..orderBy([
        (row) => OrderingTerm.desc(row.date),
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseDraft draft) async {
    _validateDraft(draft);
    await _validateNewPaymentRoute(draft);
    final requestId = _optional(draft.operationRequestId)!;
    final fingerprint = _expenseFingerprint(draft);
    final replay = await (_database.select(_database.expenses)
          ..where((row) => row.operationRequestId.equals(requestId)))
        .getSingleOrNull();
    if (replay != null) {
      if (replay.operationRequestFingerprint != fingerprint) {
        throw StateError('Expense request payload does not match replay.');
      }
      return _toDomain(replay);
    }
    final financialRepository = _financialAccountRepository;
    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    if (financialRepository != null &&
        draft.financialAccountId != null &&
        draft.financialAccountId!.isNotEmpty) {
      if (financialRepository is! TransactionSnapshotProvider) {
        throw StateError(
          'Financial account repository does not support atomic transactions.',
        );
      }
      snapshots.add(
        (financialRepository as TransactionSnapshotProvider)
            .createTransactionSnapshot(),
      );
    }

    return RepositoryTransaction.execute(snapshots, () async {
      final now = DateTime.now();
      final sequence = await _database.transaction(_takeSequence);
      final expense = ExpenseRecord(
        id: 'exp-${now.microsecondsSinceEpoch}-$sequence',
        date: DateTime(draft.date.year, draft.date.month, draft.date.day),
        category: draft.category.trim(),
        amountQirsh: draft.amountQirsh,
        notes: _optional(draft.notes),
        createdAt: now,
        createdByUserId: draft.createdByUserId.trim(),
        financialAccountId: draft.financialAccountId,
        paymentMethod: draft.paymentMethod,
        operationRequestId: requestId,
        operationRequestFingerprint: fingerprint,
      );
      await _database.into(_database.expenses).insert(_companion(expense));
      if (financialRepository != null &&
          expense.financialAccountId != null &&
          expense.financialAccountId!.isNotEmpty) {
        await financialRepository.createEntry(
          accountId: expense.financialAccountId!,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: expense.amountQirsh,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: expense.id,
          effectiveDate: expense.date,
          createdByUserId: expense.createdByUserId!,
          reference: 'مصروف: ${expense.category}',
          note: 'مصروف ${expense.amountQirsh} قرش - ${expense.category}',
          paymentMethod: expense.paymentMethod,
          approvedByUserId: draft.approvedByUserId,
          negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
          approvalSourceDocumentId: draft.operationRequestId,
        );
      }
      await _auditLogRepository.record(AuditLogDraft(
        actionType: 'expense.created',
        descriptionAr: 'تم تسجيل مصروف ${expense.category}.',
        referenceId: expense.id,
        actorId: expense.createdByUserId,
      ));
      return expense;
    });
  }

  @override
  Future<int> totalExpensesQirsh({
    required DateTime start,
    required DateTime end,
  }) async {
    final amount = _database.expenses.amountQirsh.sum();
    final query = _database.selectOnly(_database.expenses)
      ..addColumns([amount])
      ..where(_database.expenses.date.isBiggerOrEqualValue(start) &
          _database.expenses.date.isSmallerThanValue(end));
    return (await query.getSingle()).read(amount) ?? 0;
  }

  @override
  Future<void> restoreExpensesIntoEmpty(List<ExpenseRecord> expenses) =>
      _database.transaction(() async {
        if (await _database.expenses.count().getSingle() != 0) {
          throw StateError('Expenses repository is not empty.');
        }
        _validateRestored(expenses);
        for (final expense in expenses) {
          await _database.into(_database.expenses).insert(_companion(expense));
        }
        var maximum = 0;
        for (final expense in expenses) {
          final value = int.tryParse(expense.id.split('-').last) ?? 0;
          if (value > maximum) maximum = value;
        }
        await _database.repositorySequences.insertOnConflictUpdate(
          db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey,
            nextValue: maximum + 1,
          ),
        );
      });

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.expenses).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftExpenseSnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((value) => value.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.repositorySequences.insertOnConflictUpdate(
      db.RepositorySequencesCompanion.insert(
        repository: _sequenceKey,
        nextValue: value + 1,
      ),
    );
    return value;
  }

  db.ExpensesCompanion _companion(ExpenseRecord expense) =>
      db.ExpensesCompanion.insert(
        id: expense.id,
        date: expense.date,
        category: expense.category,
        amountQirsh: expense.amountQirsh,
        notes: Value(expense.notes),
        createdAt: expense.createdAt.microsecondsSinceEpoch,
        financialAccountId: Value(expense.financialAccountId),
        paymentMethod: Value(expense.paymentMethod?.name),
        createdByUserId: Value(expense.createdByUserId),
        operationRequestId: Value(expense.operationRequestId),
        operationRequestFingerprint: Value(expense.operationRequestFingerprint),
      );

  ExpenseRecord _toDomain(db.ExpenseRow row) => ExpenseRecord(
        id: row.id,
        date: row.date,
        category: row.category,
        amountQirsh: row.amountQirsh,
        notes: row.notes,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(row.createdAt),
        createdByUserId: row.createdByUserId,
        financialAccountId: row.financialAccountId,
        paymentMethod: _decodePaymentMethod(row.paymentMethod),
        operationRequestId: row.operationRequestId,
        operationRequestFingerprint: row.operationRequestFingerprint,
      );

  PaymentMethod? _decodePaymentMethod(String? value) {
    if (value == null) return null;
    for (final method in PaymentMethod.values) {
      if (method.name == value) return method;
    }
    throw FormatException('Unknown expense payment method: $value');
  }

  void _validateDraft(ExpenseDraft draft) {
    if (draft.category.trim().isEmpty) {
      throw ArgumentError.value(
        draft.category,
        'category',
        'Expense category is required.',
      );
    }
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(
        draft.amountQirsh,
        'amountQirsh',
        'Expense amount must be positive.',
      );
    }
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.createdByUserId,
        'createdByUserId',
        'Expense actor identity is required.',
      );
    }
    if (_optional(draft.operationRequestId) == null) {
      throw ArgumentError.value(
        draft.operationRequestId,
        'operationRequestId',
        'Expense operation request id is required.',
      );
    }
  }

  Future<void> _validateNewPaymentRoute(ExpenseDraft draft) async {
    final repository = _financialAccountRepository;
    if (repository == null) return;
    final accountId = _optional(draft.financialAccountId);
    if (accountId == null) {
      throw StateError('الحساب المالي مطلوب لتسجيل المصروف.');
    }
    final paymentMethod = draft.paymentMethod;
    if (paymentMethod == null) {
      throw StateError('طريقة الدفع مطلوبة لتسجيل المصروف.');
    }
    final account = await repository.accountById(accountId);
    PaymentRoutingPolicy.validateAccount(
      account: account,
      paymentMethod: paymentMethod,
    );
  }

  void _validateRestored(List<ExpenseRecord> expenses) {
    final ids = <String>{};
    for (final expense in expenses) {
      if (!expense.hasValidId ||
          expense.category.trim().isEmpty ||
          expense.amountQirsh <= 0) {
        throw StateError('Invalid expense backup record.');
      }
      if (!ids.add(expense.id)) throw StateError('Duplicate expense id.');
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _expenseFingerprint(ExpenseDraft draft) => [
        draft.date.toUtc().toIso8601String(),
        draft.category.trim(),
        draft.amountQirsh,
        draft.notes?.trim() ?? '',
        draft.financialAccountId?.trim() ?? '',
        draft.paymentMethod?.name ?? '',
        draft.createdByUserId.trim(),
      ].join('|');
}

class _DriftExpenseSnapshot extends SnapshotHolder {
  _DriftExpenseSnapshot(this.repository);

  final DriftExpenseRepository repository;
  List<ExpenseRecord>? _expenses;

  @override
  Future<void> capture() async => _expenses = await repository.listExpenses();

  @override
  Future<void> rollback() async {
    final expenses = _expenses;
    if (expenses == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreExpensesIntoEmpty(expenses);
  }
}
