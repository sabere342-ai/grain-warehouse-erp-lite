import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class SupplierPaymentRecord {
  const SupplierPaymentRecord({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.amountQirsh,
    required this.createdAt,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
  });

  final String id;
  final String supplierId;
  final DateTime date;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;

  bool get hasValidId => id.trim().isNotEmpty;
}

class SupplierPaymentDraft {
  const SupplierPaymentDraft({
    required this.supplierId,
    required this.date,
    required this.amountQirsh,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.approvedByUserId,
    this.negativeBalanceApprovalId,
    this.operationRequestId,
  });

  final String supplierId;
  final DateTime date;
  final int amountQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? approvedByUserId;
  final String? negativeBalanceApprovalId;
  final String? operationRequestId;
}
