import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/financial_account_statement_result.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only account-statement projection for authorized financial reporters.
final class FinancialAccountStatementTool implements AiTool {
  const FinancialAccountStatementTool({
    required FinancialAccountStatementReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialAccountStatementReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_account_statement';

  @override
  String get name => 'Financial account statement';

  @override
  String get description =>
      'Shows the existing financial account statement for one account.';

  @override
  List<AiToolParameter> get parameters => const [
        AiToolParameter(
          id: 'financialAccountId',
          type: AiParameterType.string,
          description: 'Existing financial account identifier.',
          required: true,
        ),
      ];

  AiExecutionMode get requiredExecutionMode => AiExecutionMode.readOnly;
  bool get requiresConfirmation => false;

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    if (parameters.length != 1 ||
        !parameters.containsKey('financialAccountId')) {
      throw const AiToolValidationException(
        message: 'Exactly one financialAccountId parameter is required.',
        errors: [
          AiValidationError(
            field: 'parameters',
            message: 'Only financialAccountId is supported.',
          ),
        ],
      );
    }
    final financialAccountId = parameters['financialAccountId'];
    if (financialAccountId is! String || financialAccountId.trim().isEmpty) {
      throw const AiToolValidationException(
        message: 'financialAccountId must be a non-empty string.',
        errors: [
          AiValidationError(
            field: 'financialAccountId',
            message: 'A non-empty financial account identifier is required.',
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

    final report = await _reader.loadAccountStatementReport(
      financialAccountId: financialAccountId,
    );
    final entries = report.lines
        .map(
          (line) => FinancialAccountStatementEntryItem(
            entryId: line.entry.id,
            effectiveDate: line.entry.effectiveDate,
            sourceType: line.entry.sourceType,
            direction: line.entry.direction,
            amountQirsh: line.entry.amountQirsh,
            sourceDocumentId: line.entry.sourceDocumentId,
            sourceDocumentNumber: line.entry.sourceDocumentNumber,
            reference: line.entry.reference,
            note: line.entry.note,
            reversalOf: line.entry.reversalOf,
            paymentMethod: line.entry.paymentMethod,
            runningBalanceQirsh: line.runningBalanceQirsh,
          ),
        )
        .toList(growable: false);
    final data = FinancialAccountStatementResult(
      accountId: report.account.id,
      accountName: report.account.name,
      accountType: report.account.type,
      isActive: report.account.isActive,
      fromDate: report.fromDate,
      toDate: report.toDate,
      openingBalanceQirsh: report.openingBalanceQirsh,
      closingBalanceQirsh: report.closingBalanceQirsh,
      entries: entries,
    );

    return AiToolResult(
      messages: [
        data.isEmpty
            ? 'No statement entries were found for this account.'
            : 'Found ${data.entries.length} statement entries.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'entryId',
            'effectiveDate',
            'sourceType',
            'direction',
            'amountQirsh',
            'sourceDocumentId',
            'runningBalanceQirsh',
          ],
          rows: data.entries
              .map(
                (entry) => [
                  entry.entryId,
                  entry.effectiveDate.toIso8601String(),
                  entry.sourceType.name,
                  entry.direction.name,
                  entry.amountQirsh,
                  entry.sourceDocumentId,
                  entry.runningBalanceQirsh,
                ],
              )
              .toList(growable: false),
        ),
      ],
      data: data,
    );
  }
}
