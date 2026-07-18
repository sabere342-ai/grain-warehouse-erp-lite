import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Owner-only read-only projection of the canonical closing reconciliation.
final class FinancialClosingReconciliationSummaryTool implements AiTool {
  const FinancialClosingReconciliationSummaryTool({
    required FinancialClosingReconciliationReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialClosingReconciliationReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_closing_reconciliation_summary';

  @override
  String get name => 'Financial closing reconciliation summary';

  @override
  String get description =>
      'Shows the canonical financial closing and reconciliation summary.';

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
    if (caller == null || !caller.canProceed || caller.role != UserRole.owner) {
      throw const AiToolValidationException(
        message: 'You are not authorized to view financial closing reports.',
        errors: [
          AiValidationError(field: 'authorization', message: 'Not authorized.'),
        ],
      );
    }

    final report = await _reader.loadClosingReconciliationReport();
    return AiToolResult(
      messages: const ['Financial closing reconciliation report loaded.'],
      data: report,
    );
  }
}
