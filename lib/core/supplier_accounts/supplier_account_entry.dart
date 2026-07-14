enum SupplierAccountEntryType {
  purchase,
  payment,
  openingBalance,
  paymentCancellation,
  advanceApplication,
  advanceApplicationReversal,
  advanceRefundReversal;

  String get labelAr {
    switch (this) {
      case SupplierAccountEntryType.purchase:
        return 'مشتريات';
      case SupplierAccountEntryType.payment:
        return 'مدفوع';
      case SupplierAccountEntryType.paymentCancellation:
        return 'Reversed payment';
      case SupplierAccountEntryType.advanceApplication:
        return 'Supplier advance application';
      case SupplierAccountEntryType.advanceApplicationReversal:
        return 'Supplier advance application reversal';
      case SupplierAccountEntryType.advanceRefundReversal:
        return 'Supplier advance refund reversal';
      case SupplierAccountEntryType.openingBalance:
        return 'رصيد افتتاحي';
    }
  }
}

class SupplierAccountEntry {
  const SupplierAccountEntry({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.type,
    required this.debitAmountQirsh,
    required this.creditAmountQirsh,
    required this.sourceDocumentType,
    required this.sourceDocumentId,
    required this.descriptionAr,
    required this.createdAt,
    required this.createdByUserId,
  });

  final String id;
  final String supplierId;
  final DateTime date;
  final SupplierAccountEntryType type;
  final int debitAmountQirsh;
  final int creditAmountQirsh;
  final String sourceDocumentType;
  final String sourceDocumentId;
  final String descriptionAr;
  final DateTime createdAt;
  final String createdByUserId;

  bool get hasValidId => id.trim().isNotEmpty;
  int get signedBalanceImpactQirsh => debitAmountQirsh - creditAmountQirsh;
}

class SupplierStatementLine {
  const SupplierStatementLine({
    required this.entry,
    required this.runningBalanceQirsh,
  });

  final SupplierAccountEntry entry;
  final int runningBalanceQirsh;
}

class SupplierStatement {
  const SupplierStatement({
    required this.supplierId,
    required this.lines,
    required this.finalBalanceQirsh,
  });

  final String supplierId;
  final List<SupplierStatementLine> lines;
  final int finalBalanceQirsh;
}
