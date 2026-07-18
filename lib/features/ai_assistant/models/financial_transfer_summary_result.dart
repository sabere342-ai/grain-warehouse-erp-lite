/// Immutable, read-only projection of the canonical transfer report.
final class FinancialTransferSummaryRow {
  const FinancialTransferSummaryRow({
    required this.transferId,
    required this.displayNumber,
    required this.effectiveDate,
    required this.sourceAccountName,
    required this.destinationAccountName,
    required this.amountQirsh,
    required this.isReversal,
    required this.isReversed,
    this.reference,
    this.note,
    this.reversalDisplayNumber,
    this.reversalDate,
    this.reversalReason,
    this.createdByUserId,
  });

  final String transferId;
  final String displayNumber;
  final DateTime effectiveDate;
  final String sourceAccountName;
  final String destinationAccountName;
  final int amountQirsh;
  final String? reference;
  final String? note;
  final bool isReversal;
  final bool isReversed;
  final String? reversalDisplayNumber;
  final DateTime? reversalDate;
  final String? reversalReason;
  final String? createdByUserId;
}

final class FinancialTransferSummaryResult {
  FinancialTransferSummaryResult({
    required this.fromDate,
    required this.toDate,
    required List<FinancialTransferSummaryRow> rows,
    required this.totalAmountQirsh,
  })  : rows = List<FinancialTransferSummaryRow>.unmodifiable(rows),
        isEmpty = rows.isEmpty;

  final DateTime fromDate;
  final DateTime toDate;
  final List<FinancialTransferSummaryRow> rows;
  final int totalAmountQirsh;
  final bool isEmpty;
}
