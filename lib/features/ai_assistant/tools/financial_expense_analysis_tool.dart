import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only pass-through of the canonical current-month expense analysis.
final class FinancialExpenseAnalysisTool implements AiTool {
  const FinancialExpenseAnalysisTool({
    required FinancialExpenseAnalysisReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialExpenseAnalysisReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_expense_analysis';

  @override
  String get name => 'Financial expense analysis';

  @override
  String get description =>
      'Shows the canonical current-month expense analysis with optional filters.';

  @override
  List<AiToolParameter> get parameters => const [
        AiToolParameter(
          id: 'accountId',
          type: AiParameterType.string,
          description: 'Optional existing financial account identifier.',
        ),
        AiToolParameter(
          id: 'paymentMethod',
          type: AiParameterType.string,
          description: 'Optional canonical payment method name.',
        ),
        AiToolParameter(
          id: 'category',
          type: AiParameterType.string,
          description: 'Optional expense category search text.',
        ),
      ];

  AiExecutionMode get requiredExecutionMode => AiExecutionMode.readOnly;
  bool get requiresConfirmation => false;

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    const supportedKeys = {'accountId', 'paymentMethod', 'category'};
    if (parameters.keys.any((key) => !supportedKeys.contains(key))) {
      throw const AiToolValidationException(
        message: 'Only accountId, paymentMethod, and category are supported.',
        errors: [
          AiValidationError(
            field: 'parameters',
            message: 'An unsupported parameter was provided.',
          ),
        ],
      );
    }

    final hasAccountId = parameters.containsKey('accountId');
    final accountId = parameters['accountId'];
    if (hasAccountId && (accountId is! String || accountId.trim().isEmpty)) {
      throw const AiToolValidationException(
        message: 'accountId must be a non-empty string when provided.',
        errors: [
          AiValidationError(
            field: 'accountId',
            message: 'Use a non-empty financial account identifier.',
          ),
        ],
      );
    }

    final hasPaymentMethod = parameters.containsKey('paymentMethod');
    final paymentMethodValue = parameters['paymentMethod'];
    PaymentMethod? paymentMethod;
    if (hasPaymentMethod) {
      if (paymentMethodValue is! String) {
        throw const AiToolValidationException(
          message: 'paymentMethod must be a canonical payment method name.',
          errors: [
            AiValidationError(
              field: 'paymentMethod',
              message: 'Use a supported canonical payment method name.',
            ),
          ],
        );
      }
      try {
        paymentMethod = PaymentMethod.values.byName(paymentMethodValue);
      } on ArgumentError {
        throw const AiToolValidationException(
          message: 'paymentMethod must be a canonical payment method name.',
          errors: [
            AiValidationError(
              field: 'paymentMethod',
              message: 'Use a supported canonical payment method name.',
            ),
          ],
        );
      }
    }

    final hasCategory = parameters.containsKey('category');
    final category = parameters['category'];
    if (hasCategory && (category is! String || category.trim().isEmpty)) {
      throw const AiToolValidationException(
        message: 'category must be a non-empty string when provided.',
        errors: [
          AiValidationError(
            field: 'category',
            message: 'Use non-empty category search text.',
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

    final report = await _reader.loadExpenseAnalysisReport(
      accountIdFilter: accountId as String?,
      paymentMethodFilter: paymentMethod,
      categoryFilter: category as String?,
    );
    return AiToolResult(
      messages: const ['Financial expense analysis report loaded.'],
      data: report,
    );
  }
}
