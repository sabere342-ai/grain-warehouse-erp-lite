import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/financial_account_balances_result.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/services/financial_account_balance_report_reader.dart';

/// Read-only Financial Account Balance Report projection for authorized callers.
final class FinancialAccountBalancesTool implements AiTool {
  const FinancialAccountBalancesTool({
    required FinancialAccountBalanceReportReader reader,
    required AppUser? caller,
  })  : _reader = reader,
        _caller = caller;

  final FinancialAccountBalanceReportReader _reader;
  final AppUser? _caller;

  @override
  String get id => 'financial_account_balances';

  @override
  String get name => 'أرصدة الحسابات المالية';

  @override
  String get description => 'يعرض تقرير أرصدة الحسابات المالية الحالي.';

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
        message: 'لا يقبل هذا الإجراء أي معاملات.',
        errors: [AiValidationError(field: 'parameters', message: 'غير مدعوم.')],
      );
    }
    if (executionMode != requiredExecutionMode) {
      throw const AiToolValidationException(
        message: 'يتطلب هذا الإجراء وضع القراءة فقط.',
        errors: [
          AiValidationError(field: 'executionMode', message: 'غير مدعوم.')
        ],
      );
    }
    final caller = _caller;
    if (caller == null ||
        !caller.canProceed ||
        !caller.permissions.canViewFinancialReports) {
      throw const AiToolValidationException(
        message: 'ليس لديك صلاحية عرض التقارير المالية.',
        errors: [
          AiValidationError(field: 'authorization', message: 'غير مصرح.')
        ],
      );
    }

    final report = await _reader.loadAccountBalanceReport();
    final accounts = report.rows
        .map((row) => FinancialAccountBalanceItem(
              accountId: row.account.id,
              accountName: row.account.name,
              accountType: row.account.type,
              isActive: row.account.isActive,
              openingBalanceQirsh: row.openingBalanceQirsh,
              totalInflowsQirsh: row.totalInflowsQirsh,
              totalOutflowsQirsh: row.totalOutflowsQirsh,
              currentBalanceQirsh: row.closingBalanceQirsh,
            ))
        .toList(growable: false);
    final data = FinancialAccountBalancesResult(
      accounts: accounts,
      totals: FinancialAccountBalanceTotals(
        openingBalanceQirsh: report.totalOpeningQirsh,
        totalInflowsQirsh: report.totalInflowsQirsh,
        totalOutflowsQirsh: report.totalOutflowsQirsh,
        currentBalanceQirsh: report.totalClosingQirsh,
      ),
    );

    return AiToolResult(
      messages: [
        data.isEmpty
            ? 'لا توجد حسابات مالية.'
            : 'تم العثور على ${data.accounts.length} حساب مالي.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'accountId',
            'accountName',
            'accountType',
            'isActive',
            'openingBalance',
            'totalInflows',
            'totalOutflows',
            'currentBalance',
          ],
          rows: data.accounts
              .map((account) => [
                    account.accountId,
                    account.accountName,
                    account.accountType.name,
                    account.isActive,
                    account.openingBalanceQirsh,
                    account.totalInflowsQirsh,
                    account.totalOutflowsQirsh,
                    account.currentBalanceQirsh,
                  ])
              .toList(growable: false),
        ),
      ],
      data: data,
    );
  }
}
