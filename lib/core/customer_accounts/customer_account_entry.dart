enum CustomerAccountEntryType {
  creditSale,
  cashSale,
  collection,
  openingBalance,
  saleCancellation,
  collectionCancellation;

  String get labelAr {
    switch (this) {
      case CustomerAccountEntryType.creditSale:
        return '\u0628\u064a\u0639 \u0622\u062c\u0644';
      case CustomerAccountEntryType.cashSale:
        return '\u0628\u064a\u0639 \u0646\u0642\u062f\u064a';
      case CustomerAccountEntryType.collection:
        return '\u062a\u062d\u0635\u064a\u0644';
      case CustomerAccountEntryType.openingBalance:
        return '\u0631\u0635\u064a\u062f \u0627\u0641\u062a\u062a\u0627\u062d\u064a';
      case CustomerAccountEntryType.saleCancellation:
        return '\u0625\u0644\u063a\u0627\u0621 \u0628\u064a\u0639';
      case CustomerAccountEntryType.collectionCancellation:
        return '\u0639\u0643\u0633 \u062a\u062d\u0635\u064a\u0644';
    }
  }
}

class CustomerAccountEntry {
  const CustomerAccountEntry({
    required this.id,
    required this.customerId,
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
  final String customerId;
  final DateTime date;
  final CustomerAccountEntryType type;
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

class CustomerStatementLine {
  const CustomerStatementLine({
    required this.entry,
    required this.runningBalanceQirsh,
  });

  final CustomerAccountEntry entry;
  final int runningBalanceQirsh;
}

class CustomerStatement {
  const CustomerStatement({
    required this.customerId,
    required this.lines,
    required this.finalBalanceQirsh,
  });

  final String customerId;
  final List<CustomerStatementLine> lines;
  final int finalBalanceQirsh;
}
