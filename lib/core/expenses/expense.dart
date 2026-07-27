import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

enum ExpenseAccountingClassification {
  operating,
  capital,
  nonOperating;

  String get labelAr => switch (this) {
        ExpenseAccountingClassification.operating => 'تشغيلي',
        ExpenseAccountingClassification.capital => 'رأسمالي',
        ExpenseAccountingClassification.nonOperating => 'غير تشغيلي',
      };
}

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
    this.accountingClassification,
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
  final ExpenseAccountingClassification? accountingClassification;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get affectsOperatingProfit =>
      accountingClassification == ExpenseAccountingClassification.operating;

  ExpenseRecord copyWithAccountingClassification(
    ExpenseAccountingClassification value,
  ) =>
      ExpenseRecord(
        id: id,
        date: date,
        category: category,
        amountQirsh: amountQirsh,
        createdAt: createdAt,
        createdByUserId: createdByUserId,
        notes: notes,
        financialAccountId: financialAccountId,
        paymentMethod: paymentMethod,
        operationRequestId: operationRequestId,
        operationRequestFingerprint: operationRequestFingerprint,
        accountingClassification: value,
      );
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.date,
    required this.category,
    required this.amountQirsh,
    required this.createdByUserId,
    required this.operationRequestId,
    required this.accountingClassification,
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
  final ExpenseAccountingClassification accountingClassification;
}
