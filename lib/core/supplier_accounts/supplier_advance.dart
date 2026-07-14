import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class SupplierAdvance {
  const SupplierAdvance({
    required this.id,
    required this.supplierId,
    required this.sourcePaymentId,
    required this.financialAccountId,
    required this.amountQirsh,
    required this.createdAt,
    required this.createdByUserId,
    required this.ownerApprovalId,
    required this.operationRequestId,
    this.paymentMethod,
    this.reversedAt,
    this.reversedByUserId,
  });

  final String id;
  final String supplierId;
  final String sourcePaymentId;
  final String financialAccountId;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String ownerApprovalId;
  final String operationRequestId;
  final PaymentMethod? paymentMethod;
  final DateTime? reversedAt;
  final String? reversedByUserId;

  bool get isReversed => reversedAt != null;
  bool get hasValidId => id.trim().isNotEmpty;
}

class SupplierAdvanceApplication {
  const SupplierAdvanceApplication({
    required this.id,
    required this.advanceId,
    required this.supplierId,
    required this.amountQirsh,
    required this.appliedAt,
    required this.createdByUserId,
    required this.operationRequestId,
    required this.supplierLedgerEntryId,
    this.reversedAt,
    this.reversedByUserId,
    this.reversalReason,
    this.reversalLedgerEntryId,
  });

  final String id;
  final String advanceId;
  final String supplierId;
  final int amountQirsh;
  final DateTime appliedAt;
  final String createdByUserId;
  final String operationRequestId;
  final String supplierLedgerEntryId;
  final DateTime? reversedAt;
  final String? reversedByUserId;
  final String? reversalReason;
  final String? reversalLedgerEntryId;

  bool get isReversed => reversedAt != null;
  bool get hasValidId => id.trim().isNotEmpty;
}

class SupplierAdvanceRefund {
  const SupplierAdvanceRefund({
    required this.id,
    required this.advanceId,
    required this.supplierId,
    required this.financialAccountId,
    required this.amountQirsh,
    required this.refundedAt,
    required this.createdByUserId,
    required this.operationRequestId,
    required this.financialEntryId,
    this.reversedAt,
    this.reversedByUserId,
    this.reversalReason,
    this.reversalFinancialEntryId,
  });

  final String id;
  final String advanceId;
  final String supplierId;
  final String financialAccountId;
  final int amountQirsh;
  final DateTime refundedAt;
  final String createdByUserId;
  final String operationRequestId;
  final String financialEntryId;
  final DateTime? reversedAt;
  final String? reversedByUserId;
  final String? reversalReason;
  final String? reversalFinancialEntryId;

  bool get isReversed => reversedAt != null;
  bool get hasValidId => id.trim().isNotEmpty;
}

class SupplierAdvanceApplicationDraft {
  const SupplierAdvanceApplicationDraft({
    required this.advanceId,
    required this.supplierId,
    required this.amountQirsh,
    required this.date,
    required this.createdByUserId,
    required this.operationRequestId,
  });

  final String advanceId;
  final String supplierId;
  final int amountQirsh;
  final DateTime date;
  final String createdByUserId;
  final String operationRequestId;
}

class SupplierAdvanceRefundDraft {
  const SupplierAdvanceRefundDraft({
    required this.advanceId,
    required this.amountQirsh,
    required this.date,
    required this.createdByUserId,
    required this.operationRequestId,
    this.financialAccountId,
    this.paymentMethod,
  });

  final String advanceId;
  final int amountQirsh;
  final DateTime date;
  final String createdByUserId;
  final String operationRequestId;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
}
