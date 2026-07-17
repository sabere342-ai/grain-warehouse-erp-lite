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

class CustomerCollectionsByAccountDetail {
  const CustomerCollectionsByAccountDetail({
    required this.entryId,
    this.sourceDocumentId,
    this.customerId,
    required this.customerName,
    required this.accountId,
    required this.accountName,
    required this.timestamp,
    required this.isReversal,
    required this.amountQirsh,
    required this.sourceType,
    this.reference,
    this.reversalOfEntryId,
  });

  final String entryId;
  final String? sourceDocumentId;
  final String? customerId;
  final String customerName;
  final String accountId;
  final String accountName;
  final DateTime timestamp;
  final bool isReversal;
  final int amountQirsh;
  final FinancialAccountEntrySource sourceType;
  final String? reference;
  final String? reversalOfEntryId;

  bool get isUnresolved => customerId == null;
}

class CustomerCollectionsByAccountAccountSummary {
  const CustomerCollectionsByAccountAccountSummary({
    required this.account,
    required this.grossCollectionsQirsh,
    required this.reversalsQirsh,
    required this.netCollectionsQirsh,
  });

  final FinancialAccount account;
  final int grossCollectionsQirsh;
  final int reversalsQirsh;
  final int netCollectionsQirsh;
}

class CustomerCollectionsByAccountCustomerSummary {
  const CustomerCollectionsByAccountCustomerSummary({
    required this.customerId,
    required this.customerName,
    required this.grossCollectionsQirsh,
    required this.reversalsQirsh,
    required this.netCollectionsQirsh,
  });

  final String? customerId;
  final String customerName;
  final int grossCollectionsQirsh;
  final int reversalsQirsh;
  final int netCollectionsQirsh;

  bool get isUnresolved => customerId == null;
}

class CustomerCollectionsByAccountReport {
  const CustomerCollectionsByAccountReport({
    required this.fromDate,
    required this.toDate,
    required this.accountSummaries,
    required this.customerSummaries,
    required this.details,
    required this.totalGrossCollectionsQirsh,
    required this.totalReversalsQirsh,
    required this.totalNetCollectionsQirsh,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<CustomerCollectionsByAccountAccountSummary> accountSummaries;
  final List<CustomerCollectionsByAccountCustomerSummary> customerSummaries;
  final List<CustomerCollectionsByAccountDetail> details;
  final int totalGrossCollectionsQirsh;
  final int totalReversalsQirsh;
  final int totalNetCollectionsQirsh;
}

class SupplierSettlementsByAccountDetail {
  const SupplierSettlementsByAccountDetail({
    required this.entryId,
    this.sourceDocumentId,
    this.supplierId,
    required this.supplierName,
    required this.accountId,
    required this.accountName,
    required this.timestamp,
    required this.isReversal,
    required this.amountQirsh,
    required this.sourceType,
    this.reference,
    this.reversalOfEntryId,
  });

  final String entryId;
  final String? sourceDocumentId;
  final String? supplierId;
  final String supplierName;
  final String accountId;
  final String accountName;
  final DateTime timestamp;
  final bool isReversal;
  final int amountQirsh;
  final FinancialAccountEntrySource sourceType;
  final String? reference;
  final String? reversalOfEntryId;

  bool get isUnresolved => supplierId == null;
}

class SupplierSettlementsByAccountAccountSummary {
  const SupplierSettlementsByAccountAccountSummary({
    required this.account,
    required this.grossSettlementsQirsh,
    required this.reversalsQirsh,
    required this.netSettlementsQirsh,
  });

  final FinancialAccount account;
  final int grossSettlementsQirsh;
  final int reversalsQirsh;
  final int netSettlementsQirsh;
}

class SupplierSettlementsByAccountSupplierSummary {
  const SupplierSettlementsByAccountSupplierSummary({
    required this.supplierId,
    required this.supplierName,
    required this.grossSettlementsQirsh,
    required this.reversalsQirsh,
    required this.netSettlementsQirsh,
  });

  final String? supplierId;
  final String supplierName;
  final int grossSettlementsQirsh;
  final int reversalsQirsh;
  final int netSettlementsQirsh;

  bool get isUnresolved => supplierId == null;
}

class SupplierSettlementsByAccountReport {
  const SupplierSettlementsByAccountReport({
    required this.fromDate,
    required this.toDate,
    required this.accountSummaries,
    required this.supplierSummaries,
    required this.details,
    required this.totalGrossSettlementsQirsh,
    required this.totalReversalsQirsh,
    required this.totalNetSettlementsQirsh,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<SupplierSettlementsByAccountAccountSummary> accountSummaries;
  final List<SupplierSettlementsByAccountSupplierSummary> supplierSummaries;
  final List<SupplierSettlementsByAccountDetail> details;
  final int totalGrossSettlementsQirsh;
  final int totalReversalsQirsh;
  final int totalNetSettlementsQirsh;
}

enum AdvancesAndRefundsPartyType {
  customer,
  supplier;

  String get labelAr {
    switch (this) {
      case AdvancesAndRefundsPartyType.customer:
        return 'عميل';
      case AdvancesAndRefundsPartyType.supplier:
        return 'مورد';
    }
  }
}

class AdvancesAndRefundsDetail {
  const AdvancesAndRefundsDetail({
    required this.entryId,
    required this.accountId,
    required this.accountName,
    required this.partyType,
    this.entityId,
    required this.entityName,
    required this.timestamp,
    required this.sourceType,
    required this.isReversal,
    required this.amountQirsh,
    required this.signedCashEffect,
    this.reference,
    this.sourceDocumentId,
    this.reversalOfEntryId,
  });

  final String entryId;
  final String accountId;
  final String accountName;
  final AdvancesAndRefundsPartyType partyType;
  final String? entityId;
  final String entityName;
  final DateTime timestamp;
  final FinancialAccountEntrySource sourceType;
  final bool isReversal;
  final int amountQirsh;
  final int signedCashEffect;
  final String? reference;
  final String? sourceDocumentId;
  final String? reversalOfEntryId;

  bool get isUnresolved => entityId == null;
}

class AdvancesAndRefundsAccountSummary {
  const AdvancesAndRefundsAccountSummary({
    required this.account,
    required this.customerGrossRefundOutflow,
    required this.customerRefundReversals,
    required this.customerNetRefundOutflow,
    required this.supplierGrossRefundInflow,
    required this.supplierRefundReversals,
    required this.supplierNetRefundInflow,
    required this.signedNetCashEffect,
    required this.detailCount,
  });

  final FinancialAccount account;
  final int customerGrossRefundOutflow;
  final int customerRefundReversals;
  final int customerNetRefundOutflow;
  final int supplierGrossRefundInflow;
  final int supplierRefundReversals;
  final int supplierNetRefundInflow;
  final int signedNetCashEffect;
  final int detailCount;
}

class AdvancesAndRefundsEntitySummary {
  const AdvancesAndRefundsEntitySummary({
    required this.partyType,
    this.entityId,
    required this.entityName,
    required this.grossAmount,
    required this.reversalAmount,
    required this.netAmount,
    required this.accountCount,
    required this.detailCount,
  });

  final AdvancesAndRefundsPartyType partyType;
  final String? entityId;
  final String entityName;
  final int grossAmount;
  final int reversalAmount;
  final int netAmount;
  final int accountCount;
  final int detailCount;

  bool get isUnresolved => entityId == null;
}

class AdvancesAndRefundsReport {
  const AdvancesAndRefundsReport({
    required this.fromDate,
    required this.toDate,
    required this.details,
    required this.accountSummaries,
    required this.customerSummaries,
    required this.supplierSummaries,
    required this.totalCustomerGrossRefundOutflow,
    required this.totalCustomerRefundReversals,
    required this.totalCustomerNetRefundOutflow,
    required this.totalSupplierGrossRefundInflow,
    required this.totalSupplierRefundReversals,
    required this.totalSupplierNetRefundInflow,
    required this.signedGrandCashEffect,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final List<AdvancesAndRefundsDetail> details;
  final List<AdvancesAndRefundsAccountSummary> accountSummaries;
  final List<AdvancesAndRefundsEntitySummary> customerSummaries;
  final List<AdvancesAndRefundsEntitySummary> supplierSummaries;
  final int totalCustomerGrossRefundOutflow;
  final int totalCustomerRefundReversals;
  final int totalCustomerNetRefundOutflow;
  final int totalSupplierGrossRefundInflow;
  final int totalSupplierRefundReversals;
  final int totalSupplierNetRefundInflow;
  final int signedGrandCashEffect;
}
