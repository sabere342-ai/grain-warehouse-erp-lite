import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/financial_advances_and_refunds_summary_result.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only advances-and-refunds report projection for authorized users.
final class FinancialAdvancesAndRefundsSummaryTool implements AiTool {
  const FinancialAdvancesAndRefundsSummaryTool({
    required FinancialAdvancesAndRefundsReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialAdvancesAndRefundsReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_advances_and_refunds_summary';

  @override
  String get name => 'Financial advances and refunds summary';

  @override
  String get description =>
      'Shows the existing financial advances and refunds report summary.';

  @override
  List<AiToolParameter> get parameters => const [];

  AiExecutionMode get requiredExecutionMode => AiExecutionMode.readOnly;
  bool get requiresConfirmation => false;

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    if (parameters.isNotEmpty) {
      throw const AiToolValidationException(
        message: 'This action does not accept parameters.',
        errors: [
          AiValidationError(
            field: 'parameters',
            message: 'Only an empty object is supported.',
          ),
        ],
      );
    }
    if (executionMode != requiredExecutionMode) {
      throw const AiToolValidationException(
        message: 'This action requires read-only execution mode.',
        errors: [
          AiValidationError(
            field: 'executionMode',
            message: 'Only readOnly is supported.',
          ),
        ],
      );
    }
    final caller = _caller;
    if (caller == null ||
        !caller.canProceed ||
        !caller.permissions.canViewFinancialReports) {
      throw const AiToolValidationException(
        message: 'You are not authorized to view financial reports.',
        errors: [
          AiValidationError(field: 'authorization', message: 'Not authorized.'),
        ],
      );
    }

    final report = await _reader.loadAdvancesAndRefundsReport();
    final data = FinancialAdvancesAndRefundsSummaryResult(
      fromDate: report.fromDate,
      toDate: report.toDate,
      details: report.details
          .map(
            (detail) => FinancialAdvancesAndRefundsDetailItem(
              entryId: detail.entryId,
              accountId: detail.accountId,
              accountName: detail.accountName,
              partyType: detail.partyType,
              entityId: detail.entityId,
              entityName: detail.entityName,
              timestamp: detail.timestamp,
              sourceType: detail.sourceType,
              isReversal: detail.isReversal,
              amountQirsh: detail.amountQirsh,
              signedCashEffectQirsh: detail.signedCashEffect,
              reference: detail.reference,
              sourceDocumentId: detail.sourceDocumentId,
              reversalOfEntryId: detail.reversalOfEntryId,
            ),
          )
          .toList(growable: false),
      accountSummaries: report.accountSummaries
          .map(
            (summary) => FinancialAdvancesAndRefundsAccountSummaryItem(
              accountId: summary.account.id,
              accountName: summary.account.name,
              accountType: summary.account.type,
              isActive: summary.account.isActive,
              customerGrossRefundOutflowQirsh:
                  summary.customerGrossRefundOutflow,
              customerRefundReversalsQirsh: summary.customerRefundReversals,
              customerNetRefundOutflowQirsh: summary.customerNetRefundOutflow,
              supplierGrossRefundInflowQirsh: summary.supplierGrossRefundInflow,
              supplierRefundReversalsQirsh: summary.supplierRefundReversals,
              supplierNetRefundInflowQirsh: summary.supplierNetRefundInflow,
              signedNetCashEffectQirsh: summary.signedNetCashEffect,
              detailCount: summary.detailCount,
            ),
          )
          .toList(growable: false),
      customerSummaries: report.customerSummaries
          .map(_mapEntitySummary)
          .toList(growable: false),
      supplierSummaries: report.supplierSummaries
          .map(_mapEntitySummary)
          .toList(growable: false),
      totalCustomerGrossRefundOutflowQirsh:
          report.totalCustomerGrossRefundOutflow,
      totalCustomerRefundReversalsQirsh: report.totalCustomerRefundReversals,
      totalCustomerNetRefundOutflowQirsh: report.totalCustomerNetRefundOutflow,
      totalSupplierGrossRefundInflowQirsh:
          report.totalSupplierGrossRefundInflow,
      totalSupplierRefundReversalsQirsh: report.totalSupplierRefundReversals,
      totalSupplierNetRefundInflowQirsh: report.totalSupplierNetRefundInflow,
      signedGrandCashEffectQirsh: report.signedGrandCashEffect,
    );

    return AiToolResult(
      messages: [
        data.isEmpty
            ? 'No advances and refunds report rows were found.'
            : 'Found ${data.details.length} advances and refunds report rows.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'entryId',
            'accountName',
            'partyType',
            'entityName',
            'amountQirsh',
            'signedCashEffectQirsh',
            'isReversal',
          ],
          rows: data.details
              .map(
                (detail) => [
                  detail.entryId,
                  detail.accountName,
                  detail.partyType.name,
                  detail.entityName,
                  detail.amountQirsh,
                  detail.signedCashEffectQirsh,
                  detail.isReversal,
                ],
              )
              .toList(growable: false),
        ),
      ],
      data: data,
    );
  }

  FinancialAdvancesAndRefundsEntitySummaryItem _mapEntitySummary(
    AdvancesAndRefundsEntitySummary summary,
  ) =>
      FinancialAdvancesAndRefundsEntitySummaryItem(
        partyType: summary.partyType,
        entityId: summary.entityId,
        entityName: summary.entityName,
        grossAmountQirsh: summary.grossAmount,
        reversalAmountQirsh: summary.reversalAmount,
        netAmountQirsh: summary.netAmount,
        accountCount: summary.accountCount,
        detailCount: summary.detailCount,
      );
}
