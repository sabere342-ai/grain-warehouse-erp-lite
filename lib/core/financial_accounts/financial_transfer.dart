class FinancialTransfer {
  const FinancialTransfer({
    required this.id,
    required this.displayNumber,
    required this.clientRequestId,
    required this.transferReference,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.amountQirsh,
    required this.effectiveDate,
    required this.createdAt,
    required this.createdByUserId,
    required this.sourceEntryId,
    required this.destinationEntryId,
    this.note,
    this.negativeBalanceApprovalId,
    this.originalTransferId,
    this.reversalTransferId,
    this.reversalReason,
  });

  final String id;
  final String displayNumber;
  final String clientRequestId;
  final String transferReference;
  final String sourceAccountId;
  final String destinationAccountId;
  final int amountQirsh;
  final DateTime effectiveDate;
  final DateTime createdAt;
  final String createdByUserId;
  final String sourceEntryId;
  final String destinationEntryId;
  final String? note;
  final String? negativeBalanceApprovalId;
  final String? originalTransferId;
  final String? reversalTransferId;
  final String? reversalReason;

  bool get isReversal => originalTransferId != null;
  bool get isReversed => reversalTransferId != null;
}

class FinancialTransferDraft {
  const FinancialTransferDraft({
    required this.clientRequestId,
    required this.transferReference,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.amountQirsh,
    required this.effectiveDate,
    required this.createdByUserId,
    this.note,
    this.negativeBalanceApprovalId,
  });

  final String clientRequestId;
  final String transferReference;
  final String sourceAccountId;
  final String destinationAccountId;
  final int amountQirsh;
  final DateTime effectiveDate;
  final String createdByUserId;
  final String? note;
  final String? negativeBalanceApprovalId;
}
