import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

final class ConfirmedExpenseProjection {
  const ConfirmedExpenseProjection({
    required this.commandId,
    required this.localFingerprint,
    required this.businessId,
    required this.serverAccountId,
    required this.expenseId,
    required this.financialEntryId,
    required this.auditEventIds,
    required this.serverAcceptedAtUtc,
    required this.businessDate,
    required this.category,
    required this.amountQirsh,
    required this.notes,
    required this.paymentMethod,
    required this.accountingClassification,
    required this.actorAuthUserId,
    required this.balanceAfterQirsh,
  });

  final String commandId;
  final String localFingerprint;
  final String businessId;
  final String serverAccountId;
  final String expenseId;
  final String financialEntryId;
  final List<String> auditEventIds;
  final DateTime serverAcceptedAtUtc;
  final String businessDate;
  final String category;
  final int amountQirsh;
  final String? notes;
  final PaymentMethod paymentMethod;
  final ExpenseAccountingClassification accountingClassification;
  final String actorAuthUserId;
  final int balanceAfterQirsh;
}

abstract interface class ConfirmedExpenseProjectionWriter {
  Future<void> project(ConfirmedExpenseProjection value);
}
