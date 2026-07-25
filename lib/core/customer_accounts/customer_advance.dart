import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// A customer credit created only by the overpaid portion of a collection.
/// Amounts are immutable; availability is derived from applications/refunds.
class CustomerAdvance {
  const CustomerAdvance({
    required this.id,
    required this.customerId,
    required this.sourceCollectionId,
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
  final String customerId;
  final String sourceCollectionId;
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

class CustomerAdvanceApplication {
  const CustomerAdvanceApplication({
    required this.id,
    required this.advanceId,
    required this.customerId,
    required this.amountQirsh,
    required this.appliedAt,
    required this.createdByUserId,
    required this.operationRequestId,
    required this.customerLedgerEntryId,
    this.reversedAt,
    this.reversedByUserId,
    this.reversalReason,
    this.reversalLedgerEntryId,
  });

  final String id;
  final String advanceId;
  final String customerId;
  final int amountQirsh;
  final DateTime appliedAt;
  final String createdByUserId;
  final String operationRequestId;
  final String customerLedgerEntryId;
  final DateTime? reversedAt;
  final String? reversedByUserId;
  final String? reversalReason;
  final String? reversalLedgerEntryId;

  bool get isReversed => reversedAt != null;
  bool get hasValidId => id.trim().isNotEmpty;
}

class CustomerAdvanceRefund {
  const CustomerAdvanceRefund({
    required this.id,
    required this.advanceId,
    required this.customerId,
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
  final String customerId;
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

class CustomerAdvanceApplicationDraft {
  const CustomerAdvanceApplicationDraft({
    required this.advanceId,
    required this.customerId,
    required this.amountQirsh,
    required this.date,
    required this.createdByUserId,
    required this.operationRequestId,
  });

  final String advanceId;
  final String customerId;
  final int amountQirsh;
  final DateTime date;
  final String createdByUserId;
  final String operationRequestId;
}

class CustomerAdvanceRefundDraft {
  const CustomerAdvanceRefundDraft({
    required this.advanceId,
    required this.amountQirsh,
    required this.date,
    required this.createdByUserId,
    required this.operationRequestId,
    this.financialAccountId,
    this.paymentMethod,
    this.negativeBalanceApprovalId,
  });

  final String advanceId;
  final int amountQirsh;
  final DateTime date;
  final String createdByUserId;
  final String operationRequestId;

  /// Must be absent or match the original collection account.
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? negativeBalanceApprovalId;
}
