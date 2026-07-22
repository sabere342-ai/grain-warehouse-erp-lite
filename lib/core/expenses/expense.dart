import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.date,
    required this.category,
    required this.amountQirsh,
    required this.createdAt,
    this.createdByUserId,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.operationRequestId,
    this.operationRequestFingerprint,
  });

  final String id;
  final DateTime date;
  final String category;
  final int amountQirsh;
  final String? notes;
  final DateTime createdAt;
  final String? createdByUserId;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? operationRequestId;
  final String? operationRequestFingerprint;

  bool get hasValidId => id.trim().isNotEmpty;
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.date,
    required this.category,
    required this.amountQirsh,
    required this.createdByUserId,
    required this.operationRequestId,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.approvedByUserId,
    this.negativeBalanceApprovalId,
  });

  final DateTime date;
  final String category;
  final int amountQirsh;
  final String createdByUserId;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? approvedByUserId;
  final String? negativeBalanceApprovalId;

  /// Stable client-side request identity used when an approval is needed
  /// before the repository generates the final expense id.
  final String operationRequestId;
}
