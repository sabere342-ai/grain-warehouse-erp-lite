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
  restoreImport,
  salePayment,
  purchasePayment,
  customerCollection,
  supplierSettlement,
  expense,
  cancellationReversal,
  transferOut,
  transferIn,
  transferReversalOut,
  transferReversalIn;

  String get labelAr {
    switch (this) {
      case FinancialAccountEntrySource.openingBalance:
        return 'رصيد افتتاحي';
      case FinancialAccountEntrySource.manualCorrection:
        return 'تصحيح يدوي';
      case FinancialAccountEntrySource.restoreImport:
        return 'استيراد/استرجاع';
      case FinancialAccountEntrySource.salePayment:
        return 'دفعة مبيعات';
      case FinancialAccountEntrySource.purchasePayment:
        return 'دفعة مشتريات';
      case FinancialAccountEntrySource.customerCollection:
        return 'تحصيل من عميل';
      case FinancialAccountEntrySource.supplierSettlement:
        return 'تسوية مع مورد';
      case FinancialAccountEntrySource.expense:
        return 'مصروف';
      case FinancialAccountEntrySource.cancellationReversal:
        return 'عكس إلغاء';
      case FinancialAccountEntrySource.transferOut:
        return 'تحويل صادر';
      case FinancialAccountEntrySource.transferIn:
        return 'تحويل وارد';
      case FinancialAccountEntrySource.transferReversalOut:
        return 'عكس تحويل صادر';
      case FinancialAccountEntrySource.transferReversalIn:
        return 'عكس تحويل وارد';
    }
  }
}

enum PaymentMethod {
  cash,
  bankTransfer,
  mobileWallet,
  check;

  String get labelAr {
    switch (this) {
      case PaymentMethod.cash:
        return 'نقدي';
      case PaymentMethod.bankTransfer:
        return 'تحويل بنكي';
      case PaymentMethod.mobileWallet:
        return 'محفظة إلكترونية';
      case PaymentMethod.check:
        return 'شيك';
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
    this.paymentMethod,
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
  final PaymentMethod? paymentMethod;

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
