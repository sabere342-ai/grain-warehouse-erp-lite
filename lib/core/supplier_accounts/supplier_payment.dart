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
    this.settledAmountQirsh,
    this.advanceAmountQirsh = 0,
    this.cancellation,
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
  final int? settledAmountQirsh;
  final int advanceAmountQirsh;
  final SupplierPaymentCancellation? cancellation;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;
}

/// Immutable compensating operation for a posted supplier payment.
class SupplierPaymentCancellation {
  const SupplierPaymentCancellation({
    required this.id,
    required this.originalPaymentId,
    required this.cancelledAt,
    required this.cancelledByUserId,
    required this.reason,
    required this.supplierLedgerReversalEntryId,
    this.financialAccountReversalEntryId,
  });

  final String id;
  final String originalPaymentId;
  final DateTime cancelledAt;
  final String cancelledByUserId;
  final String reason;
  final String supplierLedgerReversalEntryId;
  final String? financialAccountReversalEntryId;
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
    this.overpaymentApprovalId,
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
  final String? overpaymentApprovalId;
}
