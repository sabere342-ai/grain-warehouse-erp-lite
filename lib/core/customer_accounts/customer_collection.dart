import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class CustomerCollectionRecord {
  const CustomerCollectionRecord({
    required this.id,
    required this.customerId,
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
  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  /// Portion applied to the customer's receivable. The remainder is a
  /// separately tracked customer advance and never becomes a negative debt.
  final int? settledAmountQirsh;
  final int advanceAmountQirsh;
  final CustomerCollectionCancellation? cancellation;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;
}

/// Immutable compensating operation for a posted customer collection.
class CustomerCollectionCancellation {
  const CustomerCollectionCancellation({
    required this.id,
    required this.originalCollectionId,
    required this.cancelledAt,
    required this.cancelledByUserId,
    required this.reason,
    required this.customerLedgerReversalEntryId,
    this.financialAccountReversalEntryId,
  });

  final String id;
  final String originalCollectionId;
  final DateTime cancelledAt;
  final String cancelledByUserId;
  final String reason;
  final String customerLedgerReversalEntryId;
  final String? financialAccountReversalEntryId;
}

class CustomerCollectionDraft {
  const CustomerCollectionDraft({
    required this.customerId,
    required this.date,
    required this.amountQirsh,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
    this.operationRequestId,
    this.overpaymentApprovalId,
  });

  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final String? operationRequestId;
  final String? overpaymentApprovalId;
}
