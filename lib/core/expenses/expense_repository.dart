import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseRecord>> listExpenses();
  Future<ExpenseRecord> createExpense(ExpenseDraft draft);
  Future<int> totalExpensesQirsh({
    required DateTime start,
    required DateTime end,
  });
  Future<ExpenseRecord> reclassifyExpense({
    required AppUser user,
    required String expenseId,
    required ExpenseAccountingClassification classification,
    required String reason,
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
    await _validateNewPaymentRoute(draft);
    await _financialAccountRepository?.ensureDateIsOpen(draft.date);
    final requestId = _normalizedOptionalText(draft.operationRequestId)!;
    final fingerprint = _expenseFingerprint(draft);
    for (final existing in _expenses) {
      if (existing.operationRequestId != requestId) continue;
      if (existing.operationRequestFingerprint != fingerprint) {
        throw StateError('Expense request payload does not match replay.');
      }
      return existing;
    }
    final now = DateTime.now();
    final expense = ExpenseRecord(
      id: _generateExpenseId(now),
      date: DateTime(draft.date.year, draft.date.month, draft.date.day),
      category: draft.category.trim(),
      amountQirsh: draft.amountQirsh,
      notes: _normalizedOptionalText(draft.notes),
      createdAt: now,
      createdByUserId: draft.createdByUserId.trim(),
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
      operationRequestId: requestId,
      operationRequestFingerprint: fingerprint,
      accountingClassification: draft.accountingClassification,
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
          createdByUserId: expense.createdByUserId!,
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
          actorId: expense.createdByUserId,
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
  Future<ExpenseRecord> reclassifyExpense({
    required AppUser user,
    required String expenseId,
    required ExpenseAccountingClassification classification,
    required String reason,
  }) async {
    if (user.role != UserRole.owner) {
      throw StateError('Only the owner can reclassify historical expenses.');
    }
    final normalizedReason = _normalizedOptionalText(reason);
    if (normalizedReason == null) {
      throw ArgumentError.value(reason, 'reason', 'Reason is required.');
    }
    final index = _expenses.indexWhere((value) => value.id == expenseId);
    if (index < 0) throw StateError('Expense was not found.');
    return RepositoryTransaction.execute([createTransactionSnapshot()],
        () async {
      final previous = _expenses[index];
      final updated = previous.copyWithAccountingClassification(classification);
      _expenses[index] = updated;
      await _auditLogRepository.record(AuditLogDraft(
        actionType: 'expense.accountingClassification.changed',
        descriptionAr:
            'تغيير تصنيف المصروف من ${previous.accountingClassification?.name ?? 'غير مصنف'} إلى ${classification.name}. السبب: $normalizedReason',
        referenceId: updated.id,
        actorId: user.id,
      ));
      return updated;
    });
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
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.createdByUserId,
        'createdByUserId',
        'Expense actor identity is required.',
      );
    }
    if (_normalizedOptionalText(draft.operationRequestId) == null) {
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
    final accountId = _normalizedOptionalText(draft.financialAccountId);
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

  String _expenseFingerprint(ExpenseDraft draft) => [
        draft.date.toUtc().toIso8601String(),
        draft.category.trim(),
        draft.amountQirsh,
        draft.notes?.trim() ?? '',
        draft.financialAccountId?.trim() ?? '',
        draft.paymentMethod?.name ?? '',
        draft.createdByUserId.trim(),
        draft.accountingClassification.name,
      ].join('|');

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
