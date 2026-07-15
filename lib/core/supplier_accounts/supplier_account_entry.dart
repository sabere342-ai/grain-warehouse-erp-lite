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
        return '\u0639\u0643\u0633 \u062f\u0641\u0639\u0629';
      case SupplierAccountEntryType.advanceApplication:
        return '\u062a\u0637\u0628\u064a\u0642 \u0633\u0644\u0641\u0629 \u0645\u0648\u0631\u062f';
      case SupplierAccountEntryType.advanceApplicationReversal:
        return '\u0639\u0643\u0633 \u062a\u0637\u0628\u064a\u0642 \u0633\u0644\u0641\u0629 \u0645\u0648\u0631\u062f';
      case SupplierAccountEntryType.advanceRefundReversal:
        return '\u0639\u0643\u0633 \u0627\u0633\u062a\u0631\u0627\u062f \u0633\u0644\u0641\u0629 \u0645\u0648\u0631\u062f';
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
