import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_payment_method_summary',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-05 action exactly once', () {
    final registry = AiToolRegistry([
      InventoryAttentionTool(service: _InventoryReader()),
      FinancialAccountBalancesTool(reader: _BalanceReader(), caller: _owner),
      FinancialAccountStatementTool(
        reader: _StatementReader(),
        caller: _owner,
      ),
      FinancialPaymentMethodSummaryTool(
        reader: _PaymentMethodReader(_report()),
        caller: _owner,
      ),
    ]);

    final tool = registry.findById('financial_payment_method_summary')!;
    expect(tool, isA<FinancialPaymentMethodSummaryTool>());
    expect(
      registry.all
          .where((item) => item.id == 'financial_payment_method_summary')
          .length,
      1,
    );
  });

  test('metadata is read-only and does not claim mutation capabilities', () {
    final tool = FinancialPaymentMethodSummaryTool(
      reader: _PaymentMethodReader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_payment_method_summary');
    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.description.toLowerCase(), isNot(contains('create')));
    expect(tool.description.toLowerCase(), isNot(contains('edit')));
    expect(tool.description.toLowerCase(), isNot(contains('reverse')));
  });

  test('maps canonical rows, totals, null category, and ordering exactly',
      () async {
    final report = _report();
    final reader = _PaymentMethodReader(report);
    final response = await _service(reader: reader).execute(intent);

    final data = response.data! as FinancialPaymentMethodSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(data.fromDate, report.fromDate);
    expect(data.toDate, report.toDate);
    expect(data.rows.map((row) => row.paymentMethod), [
      PaymentMethod.bankTransfer,
      null,
      PaymentMethod.cash,
    ]);
    expect(data.rows.map((row) => row.displayName),
        report.rows.map((row) => row.displayName));
    expect(data.rows.first.operationCount, 2);
    expect(data.rows.first.totalInflowsQirsh, 101);
    expect(data.rows.first.totalOutflowsQirsh, 33);
    expect(data.rows.first.netMovementQirsh, 68);
    expect(data.rows[1].paymentMethod, isNull);
    expect(data.rows[1].totalInflowsQirsh, 0);
    expect(data.rows[1].totalOutflowsQirsh, 7);
    expect(data.totals.totalInflowsQirsh, 101);
    expect(data.totals.totalOutflowsQirsh, 40);
    expect(data.totals.totalNetMovementQirsh, 61);
    expect(data.isEmpty, isFalse);
    expect(() => data.rows.add(data.rows.first), throwsUnsupportedError);
  });

  test('preserves an authorized empty canonical report immutably', () async {
    final response = await _service(
      reader: _PaymentMethodReader(_report(rows: const [])),
    ).execute(intent);

    final data = response.data! as FinancialPaymentMethodSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(data.rows, isEmpty);
    expect(data.totals.totalInflowsQirsh, 0);
    expect(data.totals.totalOutflowsQirsh, 0);
    expect(data.totals.totalNetMovementQirsh, 0);
    expect(data.isEmpty, isTrue);
    expect(
      () => data.rows.add(
        const FinancialPaymentMethodSummaryRow(
          paymentMethod: null,
          displayName: 'unused',
          operationCount: 0,
          totalInflowsQirsh: 0,
          totalOutflowsQirsh: 0,
          netMovementQirsh: 0,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('rejects every unsupported input key before the reader executes',
      () async {
    final invalidParameters = <Map<String, Object?>>[
      {'unknown': true},
      {'fromDate': '2026-01-01'},
      {'accountId': 'account-1'},
      {'paymentMethod': 'cash'},
    ];

    for (final parameters in invalidParameters) {
      final reader = _PaymentMethodReader(_report());
      final response = await _service(reader: reader).execute(
        AiIntent(
          name: 'financial_payment_method_summary',
          confidence: 1,
          parameters: parameters,
          executionMode: AiExecutionMode.readOnly,
        ),
      );

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('the typed intent contract rejects null, arrays, and scalar inputs', () {
    for (final dynamic malformed in <dynamic>[null, [], 'cash', 5, true]) {
      expect(
        () => AiIntent(
          name: 'financial_payment_method_summary',
          confidence: 1,
          parameters: malformed,
          executionMode: AiExecutionMode.readOnly,
        ),
        throwsA(isA<TypeError>()),
      );
    }
  });

  test('wrong execution mode prevents report access', () async {
    final reader = _PaymentMethodReader(_report());
    final response = await _service(reader: reader).execute(const AiIntent(
      name: 'financial_payment_method_summary',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('missing, inactive, and unauthorized callers fail closed', () async {
    for (final caller in <AppUser?>[
      null,
      _owner.copyWith(isActive: false),
      _employee
    ]) {
      final reader = _PaymentMethodReader(_report());
      final response = await AiExecutionService(
        registry: AiToolRegistry([
          FinancialPaymentMethodSummaryTool(reader: reader, caller: caller),
        ]),
      ).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('reader failures use the existing safe AI failure response', () async {
    final response =
        await _service(reader: _FailingPaymentMethodReader()).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
  });

  test('tool uses only the injected canonical report reader', () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_payment_method_summary_tool.dart',
    ).readAsString();
    expect(source, contains('FinancialPaymentMethodReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
  });
}

AiExecutionService _service({
  required FinancialPaymentMethodReportReader reader,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialPaymentMethodSummaryTool(reader: reader, caller: _owner),
      ]),
    );

final _owner = AppUser(
  id: 'owner',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
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

PaymentMethodReport _report({List<PaymentMethodReportRow>? rows}) {
  final reportRows = rows ??
      [
        _summaryRow(
          paymentMethod: PaymentMethod.bankTransfer,
          operationCount: 2,
          totalInflowsQirsh: 101,
          totalOutflowsQirsh: 33,
        ),
        _summaryRow(totalInflowsQirsh: 0, totalOutflowsQirsh: 7),
        _summaryRow(
          paymentMethod: PaymentMethod.cash,
          operationCount: 1,
          totalInflowsQirsh: 0,
          totalOutflowsQirsh: 0,
        ),
      ];
  return PaymentMethodReport(
    fromDate: DateTime(2026, 1),
    toDate: DateTime(2026, 1, 31),
    rows: reportRows,
    totalInflowsQirsh: reportRows.isEmpty ? 0 : 101,
    totalOutflowsQirsh: reportRows.isEmpty ? 0 : 40,
  );
}

PaymentMethodReportRow _summaryRow({
  PaymentMethod? paymentMethod,
  int operationCount = 1,
  int totalInflowsQirsh = 0,
  int totalOutflowsQirsh = 0,
}) =>
    PaymentMethodReportRow(
      paymentMethod: paymentMethod,
      operationCount: operationCount,
      totalInflowsQirsh: totalInflowsQirsh,
      totalOutflowsQirsh: totalOutflowsQirsh,
      bySourceType: const {},
    );

final class _PaymentMethodReader implements FinancialPaymentMethodReportReader {
  _PaymentMethodReader(this.report);

  final PaymentMethodReport report;
  int calls = 0;

  @override
  Future<PaymentMethodReport> loadPaymentMethodReport() async {
    calls++;
    return report;
  }
}

final class _FailingPaymentMethodReader
    implements FinancialPaymentMethodReportReader {
  @override
  Future<PaymentMethodReport> loadPaymentMethodReport() =>
      Future<PaymentMethodReport>.error(StateError('storage details'));
}

final class _BalanceReader implements FinancialAccountBalanceReportReader {
  @override
  Future<AccountBalanceReport> loadAccountBalanceReport() =>
      Future<AccountBalanceReport>.error(UnimplementedError());
}

final class _StatementReader implements FinancialAccountStatementReportReader {
  @override
  Future<AccountStatementReport> loadAccountStatementReport({
    required String financialAccountId,
  }) =>
      Future<AccountStatementReport>.error(UnimplementedError());
}

final class _InventoryReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() async => const [];
}
