import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseRecord>> listExpenses();
  Future<ExpenseRecord> createExpense(ExpenseDraft draft);
  Future<int> totalExpensesQirsh({
    required DateTime start,
    required DateTime end,
  });
}

abstract class DurableExpenseRepository
    implements ExpenseRepository, TransactionSnapshotProvider {
  Future<void> restoreExpensesIntoEmpty(List<ExpenseRecord> expenses);
  Future<void> clearForOwnerDataWipe();
}

class LocalExpenseRepository implements DurableExpenseRepository {
  LocalExpenseRepository({
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
  })  : _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository;

  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final List<ExpenseRecord> _expenses = [];
  int _generatedIdCounter = 0;

  @override
  Future<List<ExpenseRecord>> listExpenses() async {
    final sorted = [..._expenses]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) {
          return byDate;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return List<ExpenseRecord>.unmodifiable(sorted);
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseDraft draft) async {
    _validateDraft(draft);
    final now = DateTime.now();
    final expense = ExpenseRecord(
      id: _generateExpenseId(now),
      date: DateTime(draft.date.year, draft.date.month, draft.date.day),
      category: draft.category.trim(),
      amountQirsh: draft.amountQirsh,
      notes: _normalizedOptionalText(draft.notes),
      createdAt: now,
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
    );
    if (!expense.hasValidId) {
      throw StateError('Expense id is required.');
    }
    final faRepo = _financialAccountRepository;
    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    if (faRepo != null &&
        expense.financialAccountId != null &&
        expense.financialAccountId!.isNotEmpty) {
      if (faRepo is! TransactionSnapshotProvider) {
        throw StateError('مستودع الحسابات لا يدعم المعاملات الذرية.');
      }
      snapshots.add(
        (faRepo as TransactionSnapshotProvider).createTransactionSnapshot(),
      );
    }
    return RepositoryTransaction.execute(snapshots, () async {
      _expenses.add(expense);
      if (faRepo != null &&
          expense.financialAccountId != null &&
          expense.financialAccountId!.isNotEmpty) {
        await faRepo.createEntry(
          accountId: expense.financialAccountId!,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: expense.amountQirsh,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: expense.id,
          effectiveDate: expense.date,
          createdByUserId: 'system',
          reference: 'مصروف: ${expense.category}',
          note: 'مصروف ${expense.amountQirsh} قيرش - ${expense.category}',
          paymentMethod: expense.paymentMethod,
          approvedByUserId: draft.approvedByUserId,
          negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
          approvalSourceDocumentId: draft.operationRequestId,
        );
      }
      await _auditLogRepository.record(
        AuditLogDraft(
          actionType: 'expense.created',
          descriptionAr: 'تم تسجيل مصروف ${expense.category}.',
          referenceId: expense.id,
        ),
      );
      return expense;
    });
  }

  @override
  Future<int> totalExpensesQirsh({
    required DateTime start,
    required DateTime end,
  }) async {
    return _expenses
        .where((expense) =>
            !expense.date.isBefore(start) && expense.date.isBefore(end))
        .fold<int>(0, (total, expense) => total + expense.amountQirsh);
  }

  @override
  Future<void> restoreExpensesIntoEmpty(List<ExpenseRecord> expenses) async {
    if (_expenses.isNotEmpty) {
      throw StateError('Expenses repository is not empty.');
    }
    _validateUniqueRestoredExpenses(expenses);
    _expenses.addAll(expenses);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _expenses.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    final ownState = ObjectStateSnapshot<(List<ExpenseRecord>, int)>(
      captureState: () =>
          (List<ExpenseRecord>.from(_expenses), _generatedIdCounter),
      restoreState: (state) {
        _expenses
          ..clear()
          ..addAll(state.$1);
        _generatedIdCounter = state.$2;
      },
    );
    if (_auditLogRepository is! TransactionSnapshotProvider) {
      throw StateError('مستودع التدقيق لا يدعم المعاملات الذرية.');
    }
    return CompositeSnapshot([
      ownState,
      (_auditLogRepository as TransactionSnapshotProvider)
          .createTransactionSnapshot(),
    ]);
  }

  void _validateDraft(ExpenseDraft draft) {
    if (draft.category.trim().isEmpty) {
      throw ArgumentError.value(
          draft.category, 'category', 'Expense category is required.');
    }
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(
          draft.amountQirsh, 'amountQirsh', 'Expense amount must be positive.');
    }
  }

  void _validateUniqueRestoredExpenses(List<ExpenseRecord> expenses) {
    final ids = <String>{};
    for (final expense in expenses) {
      if (!expense.hasValidId ||
          expense.category.trim().isEmpty ||
          expense.amountQirsh <= 0) {
        throw StateError('Invalid expense backup record.');
      }
      if (!ids.add(expense.id)) {
        throw StateError('Duplicate expense id.');
      }
    }
  }

  String _generateExpenseId(DateTime now) {
    _generatedIdCounter++;
    return 'exp-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
