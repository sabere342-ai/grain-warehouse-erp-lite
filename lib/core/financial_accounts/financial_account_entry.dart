import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';

enum FinancialAccountEntryDirection {
  inflow,
  outflow;

  String get labelAr {
    switch (this) {
      case FinancialAccountEntryDirection.inflow:
        return 'وارد';
      case FinancialAccountEntryDirection.outflow:
        return 'صادر';
    }
  }
}

enum FinancialAccountEntrySource {
  openingBalance,
  manualCorrection,
  restoreImport;

  String get labelAr {
    switch (this) {
      case FinancialAccountEntrySource.openingBalance:
        return 'رصيد افتتاحي';
      case FinancialAccountEntrySource.manualCorrection:
        return 'تصحيح يدوي';
      case FinancialAccountEntrySource.restoreImport:
        return 'استيراد/استرجاع';
    }
  }
}

class FinancialAccountEntry {
  const FinancialAccountEntry({
    required this.id,
    required this.accountId,
    required this.direction,
    required this.amountQirsh,
    required this.sourceType,
    required this.sourceDocumentId,
    this.sourceDocumentNumber,
    required this.effectiveDate,
    required this.createdAt,
    required this.createdByUserId,
    this.reference,
    this.note,
    this.reversalOf,
    this.correctionGroup,
  });

  final String id;
  final String accountId;
  final FinancialAccountEntryDirection direction;
  final int amountQirsh;
  final FinancialAccountEntrySource sourceType;
  final String sourceDocumentId;
  final String? sourceDocumentNumber;
  final DateTime effectiveDate;
  final DateTime createdAt;
  final String createdByUserId;
  final String? reference;
  final String? note;
  final String? reversalOf;
  final String? correctionGroup;

  bool get hasValidId => id.trim().isNotEmpty;
  int get signedAmountQirsh =>
      direction == FinancialAccountEntryDirection.inflow
          ? amountQirsh
          : -amountQirsh;
}

class FinancialAccountStatementLine {
  const FinancialAccountStatementLine({
    required this.entry,
    required this.runningBalanceQirsh,
  });

  final FinancialAccountEntry entry;
  final int runningBalanceQirsh;
}

class FinancialAccountStatement {
  const FinancialAccountStatement({
    required this.accountId,
    required this.lines,
    required this.finalBalanceQirsh,
    required this.openingBalanceQirsh,
  });

  final String accountId;
  final List<FinancialAccountStatementLine> lines;
  final int finalBalanceQirsh;
  final int openingBalanceQirsh;
}

class FinancialAccountBalanceSummary {
  const FinancialAccountBalanceSummary({
    required this.account,
    required this.currentBalanceQirsh,
    required this.entryCount,
  });

  final FinancialAccount account;
  final int currentBalanceQirsh;
  final int entryCount;
}

class OpeningBalanceCorrectionDraft {
  const OpeningBalanceCorrectionDraft({
    required this.accountId,
    required this.correctedOpeningBalanceQirsh,
    required this.reason,
    required this.createdByUserId,
  });

  final String accountId;
  final int correctedOpeningBalanceQirsh;
  final String reason;
  final String createdByUserId;
}
