import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class AccountBalanceReportRow {
  const AccountBalanceReportRow({
    required this.account,
    required this.openingBalanceQirsh,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.entryCount,
  });

  final FinancialAccount account;
  final int openingBalanceQirsh;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int entryCount;

  int get netMovementQirsh => totalInflowsQirsh - totalOutflowsQirsh;
  int get closingBalanceQirsh => openingBalanceQirsh + netMovementQirsh;
}

class AccountBalanceReport {
  const AccountBalanceReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalOpeningQirsh,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.totalClosingQirsh,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<AccountBalanceReportRow> rows;
  final int totalOpeningQirsh;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final int totalClosingQirsh;

  int get totalNetMovementQirsh => totalInflowsQirsh - totalOutflowsQirsh;
}

class AccountStatementReportLine {
  const AccountStatementReportLine({
    required this.entry,
    required this.runningBalanceQirsh,
  });

  final FinancialAccountEntry entry;
  final int runningBalanceQirsh;

  String get reversalStatus {
    if (entry.reversalOf != null) return 'reversal';
    return 'original';
  }
}

class AccountStatementReport {
  const AccountStatementReport({
    required this.account,
    required this.fromDate,
    required this.toDate,
    required this.lines,
    required this.openingBalanceQirsh,
    required this.closingBalanceQirsh,
  });

  final FinancialAccount account;
  final DateTime fromDate;
  final DateTime toDate;
  final List<AccountStatementReportLine> lines;
  final int openingBalanceQirsh;
  final int closingBalanceQirsh;
}

class PaymentMethodReportRow {
  const PaymentMethodReportRow({
    required this.paymentMethod,
    required this.operationCount,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
    required this.bySourceType,
  });

  final PaymentMethod? paymentMethod;
  final int operationCount;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;
  final Map<FinancialAccountEntrySource, int> bySourceType;

  int get netMovementQirsh => totalInflowsQirsh - totalOutflowsQirsh;
  String get displayName => paymentMethod?.labelAr ?? 'غير محدد';
}

class PaymentMethodReport {
  const PaymentMethodReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalInflowsQirsh,
    required this.totalOutflowsQirsh,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<PaymentMethodReportRow> rows;
  final int totalInflowsQirsh;
  final int totalOutflowsQirsh;

  int get totalNetMovementQirsh => totalInflowsQirsh - totalOutflowsQirsh;
}

class TransferReportRow {
  const TransferReportRow({
    required this.transferId,
    required this.displayNumber,
    required this.effectiveDate,
    required this.sourceAccountName,
    required this.destinationAccountName,
    required this.amountQirsh,
    this.reference,
    this.note,
    required this.isReversal,
    required this.isReversed,
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

class TransferReport {
  const TransferReport({
    required this.fromDate,
    required this.toDate,
    required this.rows,
    required this.totalAmountQirsh,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<TransferReportRow> rows;
  final int totalAmountQirsh;
}

class FlowReportEntry {
  const FlowReportEntry({
    required this.entryId,
    required this.timestamp,
    required this.accountId,
    required this.accountName,
    required this.source,
    this.referenceId,
    this.description,
    required this.amountQirsh,
    required this.direction,
    required this.isReversal,
  });

  final String entryId;
  final DateTime timestamp;
  final String accountId;
  final String accountName;
  final FinancialAccountEntrySource source;
  final String? referenceId;
  final String? description;
  final int amountQirsh;
  final FinancialAccountEntryDirection direction;
  final bool isReversal;
}

class FlowReport {
  const FlowReport({
    required this.fromDate,
    required this.toDate,
    required this.entries,
    required this.totalQirsh,
    required this.sourceBreakdown,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<FlowReportEntry> entries;
  final int totalQirsh;
  final Map<FinancialAccountEntrySource, int> sourceBreakdown;
}
