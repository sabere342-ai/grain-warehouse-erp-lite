import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/supplier_payments_by_financial_account_report_reader.dart';

/// Read-only pass-through of the canonical supplier-payments account report.
final class SupplierPaymentsByFinancialAccountTool implements AiTool {
  const SupplierPaymentsByFinancialAccountTool({
    required SupplierPaymentsByFinancialAccountReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final SupplierPaymentsByFinancialAccountReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_supplier_payments_by_account';

  @override
  String get name => 'Supplier Payments by Financial Account';

  @override
  String get description =>
      'Shows canonical supplier payments for one financial account and inclusive period.';

  @override
  List<AiToolParameter> get parameters => const [
        AiToolParameter(
          id: 'financialAccountId',
          type: AiParameterType.string,
          description: 'Existing financial account identifier.',
          required: true,
        ),
        AiToolParameter(
          id: 'startDate',
          type: AiParameterType.string,
          description: 'Inclusive local business date in YYYY-MM-DD format.',
          required: true,
        ),
        AiToolParameter(
          id: 'endDate',
          type: AiParameterType.string,
          description: 'Inclusive local business date in YYYY-MM-DD format.',
          required: true,
        ),
        AiToolParameter(
          id: 'supplierId',
          type: AiParameterType.string,
          description: 'Optional existing supplier identifier.',
        ),
      ];

  AiExecutionMode get requiredExecutionMode => AiExecutionMode.readOnly;
  bool get requiresConfirmation => false;

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    const supportedKeys = {
      'financialAccountId',
      'startDate',
      'endDate',
      'supplierId',
    };
    if (parameters.keys.any((key) => !supportedKeys.contains(key)) ||
        !parameters.containsKey('financialAccountId') ||
        !parameters.containsKey('startDate') ||
        !parameters.containsKey('endDate')) {
      throw const AiToolValidationException(
        message:
            'financialAccountId, startDate, and endDate are the only required parameters.',
        errors: [
          AiValidationError(
            field: 'parameters',
            message: 'Use only the approved supplier-payments parameters.',
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

    final supplierId = parameters['supplierId'];
    if (supplierId != null &&
        (supplierId is! String || supplierId.trim().isEmpty)) {
      throw const AiToolValidationException(
        message: 'supplierId must be a non-empty string when provided.',
        errors: [
          AiValidationError(
            field: 'supplierId',
            message: 'Use a non-empty supplier identifier.',
          ),
        ],
      );
    }

    final startDate = _parseBusinessDate(parameters['startDate'], 'startDate');
    final endDate = _parseBusinessDate(parameters['endDate'], 'endDate');
    if (endDate.isBefore(startDate)) {
      throw const AiToolValidationException(
        message: 'endDate must not be earlier than startDate.',
        errors: [
          AiValidationError(
            field: 'endDate',
            message: 'Use an end date on or after startDate.',
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

    final report = await _reader.loadSupplierPaymentsByFinancialAccountReport(
      financialAccountId: financialAccountId,
      startDate: startDate,
      endDate: endDate,
      supplierId: supplierId as String?,
    );
    return AiToolResult(
      messages: const ['Supplier payments by financial account report loaded.'],
      data: report,
    );
  }

  DateTime _parseBusinessDate(Object? value, String field) {
    if (value is! String || !_datePattern.hasMatch(value)) {
      throw AiToolValidationException(
        message: '$field must use YYYY-MM-DD format.',
        errors: [
          AiValidationError(
            field: field,
            message: 'Use an exact YYYY-MM-DD local business date.',
          ),
        ],
      );
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw AiToolValidationException(
        message: '$field must be a possible calendar date.',
        errors: [
          AiValidationError(
            field: field,
            message: 'Use a possible YYYY-MM-DD local business date.',
          ),
        ],
      );
    }
    return date;
  }

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
}
