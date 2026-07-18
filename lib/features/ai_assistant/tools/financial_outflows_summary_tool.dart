import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only pass-through of the canonical current-month financial outflows.
final class FinancialOutflowsSummaryTool implements AiTool {
  const FinancialOutflowsSummaryTool({
    required FinancialOutflowsReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialOutflowsReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_outflows_summary';

  @override
  String get name => 'Financial outflows summary';

  @override
  String get description =>
      'Shows the canonical current-month financial outflows summary.';

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

    final report = await _reader.loadFinancialOutflowsReport();
    return AiToolResult(
      messages: const ['Financial outflows report loaded.'],
      data: report,
    );
  }
}
