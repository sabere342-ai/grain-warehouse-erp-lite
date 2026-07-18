import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/financial_transfer_summary_result.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only transfer-report projection for authorized financial users.
final class FinancialTransferSummaryTool implements AiTool {
  const FinancialTransferSummaryTool({
    required FinancialTransferReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialTransferReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_transfer_summary';

  @override
  String get name => 'Financial transfer summary';

  @override
  String get description =>
      'Shows the existing financial transfer report summary.';

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

    final report = await _reader.loadTransferReport();
    final rows = report.rows
        .map(
          (row) => FinancialTransferSummaryRow(
            transferId: row.transferId,
            displayNumber: row.displayNumber,
            effectiveDate: row.effectiveDate,
            sourceAccountName: row.sourceAccountName,
            destinationAccountName: row.destinationAccountName,
            amountQirsh: row.amountQirsh,
            reference: row.reference,
            note: row.note,
            isReversal: row.isReversal,
            isReversed: row.isReversed,
            reversalDisplayNumber: row.reversalDisplayNumber,
            reversalDate: row.reversalDate,
            reversalReason: row.reversalReason,
            createdByUserId: row.createdByUserId,
          ),
        )
        .toList(growable: false);
    final data = FinancialTransferSummaryResult(
      fromDate: report.fromDate,
      toDate: report.toDate,
      rows: rows,
      totalAmountQirsh: report.totalAmountQirsh,
    );

    return AiToolResult(
      messages: [
        data.isEmpty
            ? 'No transfer report rows were found.'
            : 'Found ${data.rows.length} transfer report rows.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'transferId',
            'displayNumber',
            'effectiveDate',
            'sourceAccountName',
            'destinationAccountName',
            'amountQirsh',
            'isReversal',
            'isReversed',
          ],
          rows: data.rows
              .map(
                (row) => [
                  row.transferId,
                  row.displayNumber,
                  row.effectiveDate.toIso8601String(),
                  row.sourceAccountName,
                  row.destinationAccountName,
                  row.amountQirsh,
                  row.isReversal,
                  row.isReversed,
                ],
              )
              .toList(growable: false),
        ),
      ],
      data: data,
    );
  }
}
