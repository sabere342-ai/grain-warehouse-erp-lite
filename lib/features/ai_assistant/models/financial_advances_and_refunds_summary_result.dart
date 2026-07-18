import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';

/// Immutable, read-only projection of the canonical advances-and-refunds report.
final class FinancialAdvancesAndRefundsDetailItem {
  const FinancialAdvancesAndRefundsDetailItem({
    required this.entryId,
    required this.accountId,
    required this.accountName,
    required this.partyType,
    required this.entityName,
    required this.timestamp,
    required this.sourceType,
    required this.isReversal,
    required this.amountQirsh,
    required this.signedCashEffectQirsh,
    this.entityId,
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
  final int signedCashEffectQirsh;
  final String? reference;
  final String? sourceDocumentId;
  final String? reversalOfEntryId;
}

final class FinancialAdvancesAndRefundsAccountSummaryItem {
  const FinancialAdvancesAndRefundsAccountSummaryItem({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.isActive,
    required this.customerGrossRefundOutflowQirsh,
    required this.customerRefundReversalsQirsh,
    required this.customerNetRefundOutflowQirsh,
    required this.supplierGrossRefundInflowQirsh,
    required this.supplierRefundReversalsQirsh,
    required this.supplierNetRefundInflowQirsh,
    required this.signedNetCashEffectQirsh,
    required this.detailCount,
  });

  final String accountId;
  final String accountName;
  final FinancialAccountType accountType;
  final bool isActive;
  final int customerGrossRefundOutflowQirsh;
  final int customerRefundReversalsQirsh;
  final int customerNetRefundOutflowQirsh;
  final int supplierGrossRefundInflowQirsh;
  final int supplierRefundReversalsQirsh;
  final int supplierNetRefundInflowQirsh;
  final int signedNetCashEffectQirsh;
  final int detailCount;
}

final class FinancialAdvancesAndRefundsEntitySummaryItem {
  const FinancialAdvancesAndRefundsEntitySummaryItem({
    required this.partyType,
    required this.entityName,
    required this.grossAmountQirsh,
    required this.reversalAmountQirsh,
    required this.netAmountQirsh,
    required this.accountCount,
    required this.detailCount,
    this.entityId,
  });

  final AdvancesAndRefundsPartyType partyType;
  final String? entityId;
  final String entityName;
  final int grossAmountQirsh;
  final int reversalAmountQirsh;
  final int netAmountQirsh;
  final int accountCount;
  final int detailCount;
}

final class FinancialAdvancesAndRefundsSummaryResult {
  FinancialAdvancesAndRefundsSummaryResult({
    required this.fromDate,
    required this.toDate,
    required List<FinancialAdvancesAndRefundsDetailItem> details,
    required List<FinancialAdvancesAndRefundsAccountSummaryItem>
        accountSummaries,
    required List<FinancialAdvancesAndRefundsEntitySummaryItem>
        customerSummaries,
    required List<FinancialAdvancesAndRefundsEntitySummaryItem>
        supplierSummaries,
    required this.totalCustomerGrossRefundOutflowQirsh,
    required this.totalCustomerRefundReversalsQirsh,
    required this.totalCustomerNetRefundOutflowQirsh,
    required this.totalSupplierGrossRefundInflowQirsh,
    required this.totalSupplierRefundReversalsQirsh,
    required this.totalSupplierNetRefundInflowQirsh,
    required this.signedGrandCashEffectQirsh,
  })  : details = List<FinancialAdvancesAndRefundsDetailItem>.unmodifiable(
          details,
        ),
        accountSummaries =
            List<FinancialAdvancesAndRefundsAccountSummaryItem>.unmodifiable(
          accountSummaries,
        ),
        customerSummaries =
            List<FinancialAdvancesAndRefundsEntitySummaryItem>.unmodifiable(
          customerSummaries,
        ),
        supplierSummaries =
            List<FinancialAdvancesAndRefundsEntitySummaryItem>.unmodifiable(
          supplierSummaries,
        ),
        isEmpty = details.isEmpty;

  final DateTime fromDate;
  final DateTime toDate;
  final List<FinancialAdvancesAndRefundsDetailItem> details;
  final List<FinancialAdvancesAndRefundsAccountSummaryItem> accountSummaries;
  final List<FinancialAdvancesAndRefundsEntitySummaryItem> customerSummaries;
  final List<FinancialAdvancesAndRefundsEntitySummaryItem> supplierSummaries;
  final int totalCustomerGrossRefundOutflowQirsh;
  final int totalCustomerRefundReversalsQirsh;
  final int totalCustomerNetRefundOutflowQirsh;
  final int totalSupplierGrossRefundInflowQirsh;
  final int totalSupplierRefundReversalsQirsh;
  final int totalSupplierNetRefundInflowQirsh;
  final int signedGrandCashEffectQirsh;
  final bool isEmpty;
}
