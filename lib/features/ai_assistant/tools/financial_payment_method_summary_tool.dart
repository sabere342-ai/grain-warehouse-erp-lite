import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/financial_payment_method_summary_result.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only payment-method report projection for authorized financial users.
final class FinancialPaymentMethodSummaryTool implements AiTool {
  const FinancialPaymentMethodSummaryTool({
    required FinancialPaymentMethodReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialPaymentMethodReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_payment_method_summary';

  @override
  String get name => 'Financial payment method summary';

  @override
  String get description =>
      'Shows the existing financial summary grouped by payment method.';

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

    final report = await _reader.loadPaymentMethodReport();
    final rows = report.rows
        .map(
          (row) => FinancialPaymentMethodSummaryRow(
            paymentMethod: row.paymentMethod,
            displayName: row.displayName,
            operationCount: row.operationCount,
            totalInflowsQirsh: row.totalInflowsQirsh,
            totalOutflowsQirsh: row.totalOutflowsQirsh,
            netMovementQirsh: row.netMovementQirsh,
          ),
        )
        .toList(growable: false);
    final data = FinancialPaymentMethodSummaryResult(
      fromDate: report.fromDate,
      toDate: report.toDate,
      rows: rows,
      totals: FinancialPaymentMethodSummaryTotals(
        totalInflowsQirsh: report.totalInflowsQirsh,
        totalOutflowsQirsh: report.totalOutflowsQirsh,
        totalNetMovementQirsh: report.totalNetMovementQirsh,
      ),
    );

    return AiToolResult(
      messages: [
        data.isEmpty
            ? 'No payment method summary rows were found.'
            : 'Found ${data.rows.length} payment method summary rows.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'paymentMethod',
            'displayName',
            'operationCount',
            'totalInflowsQirsh',
            'totalOutflowsQirsh',
            'netMovementQirsh',
          ],
          rows: data.rows
              .map(
                (row) => [
                  row.paymentMethod?.name,
                  row.displayName,
                  row.operationCount,
                  row.totalInflowsQirsh,
                  row.totalOutflowsQirsh,
                  row.netMovementQirsh,
                ],
              )
              .toList(growable: false),
        ),
      ],
      data: data,
    );
  }
}
