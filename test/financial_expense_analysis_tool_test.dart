import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_expense_analysis',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-13 action exactly once', () {
    final registry = AiToolRegistry([
      FinancialExpenseAnalysisTool(
        reader: _Reader(_report()),
        caller: _financialReportsViewer,
      ),
    ]);

    expect(
      registry.findById('financial_expense_analysis'),
      isA<FinancialExpenseAnalysisTool>(),
    );
    expect(
      registry.all
          .where((tool) => tool.id == 'financial_expense_analysis')
          .length,
      1,
    );
  });

  test(
      'metadata is read-only, does not require confirmation, and lists filters',
      () {
    final tool = FinancialExpenseAnalysisTool(
      reader: _Reader(_report()),
      caller: _financialReportsViewer,
    );

    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(
      tool.parameters.map((parameter) => parameter.id),
      ['accountId', 'paymentMethod', 'category'],
    );
    expect(tool.parameters.every((parameter) => !parameter.required), isTrue);
  });

  test('authorized caller receives the exact canonical report unchanged',
      () async {
    final report = _report();
    final reader = _Reader(report);
    final response = await _service(
      reader: reader,
      caller: _financialReportsViewer,
    ).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    expect(response.tables, isEmpty);
    expect(reader.calls, 1);
    final data = response.data! as ExpenseAnalysisReport;
    expect(data.rows.map((row) => row.category), ['Utilities', 'Salaries']);
    expect(data.rows.first.totalAmountQirsh, 0);
    expect(data.rows.last.percentageOfTotal, 100.0);
    expect(data.allDetails.first.notes, isNull);
    expect(data.allDetails.last.amountQirsh, -17);
    expect(data.totalQirsh, 101);
    expect(data.grandCount, 2);
  });

  test('preserves an authorized empty canonical report', () async {
    final report = _report(empty: true);
    final response = await _service(
      reader: _Reader(report),
      caller: _financialReportsViewer,
    ).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    expect((response.data! as ExpenseAnalysisReport).rows, isEmpty);
    expect((response.data! as ExpenseAnalysisReport).totalQirsh, 0);
  });

  test('accepts empty, individual, and combined filters unchanged', () async {
    final cases = <({
      Map<String, Object?> input,
      String? accountId,
      PaymentMethod? paymentMethod,
      String? category
    })>[
      (input: {}, accountId: null, paymentMethod: null, category: null),
      (
        input: {'accountId': ' account-1 '},
        accountId: ' account-1 ',
        paymentMethod: null,
        category: null,
      ),
      (
        input: {'paymentMethod': 'bankTransfer'},
        accountId: null,
        paymentMethod: PaymentMethod.bankTransfer,
        category: null,
      ),
      (
        input: {'category': '  salaries  '},
        accountId: null,
        paymentMethod: null,
        category: '  salaries  ',
      ),
      (
        input: {
          'accountId': 'account-2',
          'paymentMethod': 'mobileWallet',
          'category': 'Utilities',
        },
        accountId: 'account-2',
        paymentMethod: PaymentMethod.mobileWallet,
        category: 'Utilities',
      ),
    ];

    for (final testCase in cases) {
      final reader = _Reader(_report());
      final response = await _service(
        reader: reader,
        caller: _financialReportsViewer,
      ).execute(
        AiIntent(
          name: 'financial_expense_analysis',
          confidence: 1,
          parameters: testCase.input,
          executionMode: AiExecutionMode.readOnly,
        ),
      );

      expect(response.isSuccess, isTrue);
      expect(reader.calls, 1);
      expect(reader.accountIdFilter, testCase.accountId);
      expect(reader.paymentMethodFilter, testCase.paymentMethod);
      expect(reader.categoryFilter, testCase.category);
    }
  });

  test('rejects unsupported keys, dates, sorting, and pagination before reader',
      () async {
    for (final parameters in <Map<String, Object?>>[
      {'startDate': '2026-07-01'},
      {'endDate': '2026-07-31'},
      {'date': '2026-07-18'},
      {'month': 7},
      {'year': 2026},
      {'from': '2026-07-01'},
      {'to': '2026-07-31'},
      {'sort': 'category'},
      {'sortBy': 'amount'},
      {'order': 'asc'},
      {'page': 1},
      {'pageSize': 10},
      {'offset': 0},
      {'limit': 10},
      {'unlisted': null},
    ]) {
      final reader = _Reader(_report());
      final response = await _service(
        reader: reader,
        caller: _financialReportsViewer,
      ).execute(
        AiIntent(
          name: 'financial_expense_analysis',
          confidence: 1,
          parameters: parameters,
          executionMode: AiExecutionMode.readOnly,
        ),
      );

      expect(response.status, AiResponseStatus.validationFailure);
      expect(reader.calls, 0);
    }
  });

  test('rejects null, blank, invalid enum, and wrong value types before reader',
      () async {
    for (final parameters in <Map<String, Object?>>[
      {'accountId': null},
      {'paymentMethod': null},
      {'category': null},
      {'accountId': '   '},
      {'category': '   '},
      {'accountId': 1},
      {'paymentMethod': 1},
      {'category': false},
      {'paymentMethod': 'cash '},
      {'paymentMethod': 'Cash'},
      {'paymentMethod': 'all'},
      {'paymentMethod': 'unknown'},
    ]) {
      final reader = _Reader(_report());
      final response = await _service(
        reader: reader,
        caller: _financialReportsViewer,
      ).execute(
        AiIntent(
          name: 'financial_expense_analysis',
          confidence: 1,
          parameters: parameters,
          executionMode: AiExecutionMode.readOnly,
        ),
      );

      expect(response.status, AiResponseStatus.validationFailure);
      expect(reader.calls, 0);
    }
  });

  test('typed intent boundary rejects non-object input forms', () {
    for (final dynamic malformed in <dynamic>[null, [], 'report', 5, true]) {
      expect(
        () => AiIntent(
          name: 'financial_expense_analysis',
          confidence: 1,
          parameters: malformed,
          executionMode: AiExecutionMode.readOnly,
        ),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('wrong execution mode prevents report access', () async {
    final reader = _Reader(_report());
    final response = await _service(
      reader: reader,
      caller: _financialReportsViewer,
    ).execute(const AiIntent(
      name: 'financial_expense_analysis',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('missing, inactive, and unauthorized callers fail before reader',
      () async {
    for (final caller in <AppUser?>[
      null,
      _financialReportsViewer.copyWith(isActive: false),
      _employee,
    ]) {
      final reader = _Reader(_report());
      final response =
          await _service(reader: reader, caller: caller).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(reader.calls, 0);
    }
  });

  test('reader failure becomes the existing safe AI failure response',
      () async {
    final response = await _service(
      reader: _FailingReader(),
      caller: _financialReportsViewer,
    ).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
  });

  test('tool and adapter delegate without repository, time, or report logic',
      () async {
    final toolSource = await File(
      'lib/features/ai_assistant/tools/financial_expense_analysis_tool.dart',
    ).readAsString();
    final readerSource = await File(
      'lib/features/ai_assistant/services/financial_account_balance_report_reader.dart',
    ).readAsString();

    expect(toolSource, contains('FinancialExpenseAnalysisReportReader'));
    expect(toolSource, isNot(contains('Repository')));
    expect(toolSource, isNot(contains('DateTime.now')));
    expect(toolSource, isNot(contains('.sort(')));
    expect(toolSource, isNot(contains('fold(')));
    expect(toolSource, isNot(contains('reduce(')));
    expect(readerSource, contains('_service.expenseAnalysisReport('));
    expect(readerSource, contains('accountIdFilter: accountIdFilter'));
    expect(readerSource, contains('paymentMethodFilter: paymentMethodFilter'));
    expect(readerSource, contains('categoryFilter: categoryFilter'));
    expect(readerSource, isNot(contains('_repository')));
    expect(readerSource, isNot(contains('DateTime.now')));
  });
}

AiExecutionService _service({
  required FinancialExpenseAnalysisReportReader reader,
  required AppUser? caller,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialExpenseAnalysisTool(reader: reader, caller: caller),
      ]),
    );

ExpenseAnalysisReport _report({bool empty = false}) => ExpenseAnalysisReport(
      fromDate: DateTime(2026, 7, 1),
      toDate: DateTime(2026, 7, 18, 12),
      rows: empty
          ? const []
          : [
              ExpenseAnalysisReportRow(
                category: 'Utilities',
                totalAmountQirsh: 0,
                count: 1,
                percentageOfTotal: 0.0,
                details: [_detail('zero', 0, null)],
              ),
              ExpenseAnalysisReportRow(
                category: 'Salaries',
                totalAmountQirsh: 101,
                count: 1,
                percentageOfTotal: 100.0,
                details: [_detail('salary', -17, 'Canonical note')],
              ),
            ],
      totalQirsh: empty ? 0 : 101,
      grandCount: empty ? 0 : 2,
      allDetails: empty
          ? const []
          : [
              _detail('zero', 0, null),
              _detail('salary', -17, 'Canonical note')
            ],
    );

ExpenseAnalysisReportDetail _detail(
        String id, int amountQirsh, String? notes) =>
    ExpenseAnalysisReportDetail(
      expenseId: id,
      date: DateTime(2026, 7, 18),
      createdAt: DateTime(2026, 7, 18, 10),
      category: id == 'zero' ? 'Utilities' : 'Salaries',
      amountQirsh: amountQirsh,
      paymentMethodLabel: 'Cash',
      accountName: 'Main account',
      notes: notes,
    );

final _financialReportsViewer = _FinancialReportsViewer(
  id: 'viewer',
  name: 'Financial viewer',
  phone: '01000000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _employee = AppUser(
  id: 'employee',
  name: 'Employee',
  phone: '01000000001',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final class _FinancialReportsViewer extends AppUser {
  const _FinancialReportsViewer({
    required super.id,
    required super.name,
    required super.phone,
    required super.role,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  @override
  Permissions get permissions => Permissions.owner;
}

final class _Reader implements FinancialExpenseAnalysisReportReader {
  _Reader(this.report);

  final ExpenseAnalysisReport report;
  int calls = 0;
  String? accountIdFilter;
  PaymentMethod? paymentMethodFilter;
  String? categoryFilter;

  @override
  Future<ExpenseAnalysisReport> loadExpenseAnalysisReport({
    String? accountIdFilter,
    PaymentMethod? paymentMethodFilter,
    String? categoryFilter,
  }) async {
    calls++;
    this.accountIdFilter = accountIdFilter;
    this.paymentMethodFilter = paymentMethodFilter;
    this.categoryFilter = categoryFilter;
    return report;
  }
}

final class _FailingReader implements FinancialExpenseAnalysisReportReader {
  @override
  Future<ExpenseAnalysisReport> loadExpenseAnalysisReport({
    String? accountIdFilter,
    PaymentMethod? paymentMethodFilter,
    String? categoryFilter,
  }) =>
      Future<ExpenseAnalysisReport>.error(StateError('storage details'));
}
