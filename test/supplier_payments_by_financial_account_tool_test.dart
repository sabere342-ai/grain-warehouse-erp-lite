import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payments_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_supplier_payments_by_account',
    confidence: 1,
    parameters: {
      'financialAccountId': 'account-1',
      'startDate': '2026-07-01',
      'endDate': '2026-07-31',
      'supplierId': 'supplier-1',
    },
    executionMode: AiExecutionMode.readOnly,
  );

  test('registers the exact BUILD-19 action once in a caller-supplied registry',
      () {
    final registry = AiToolRegistry([
      ..._existingActionIds.map(_IdTool.new),
      SupplierPaymentsByFinancialAccountTool(
        reader: _Reader(_report()),
        caller: _owner,
      ),
    ]);

    expect(registry.all, hasLength(12));
    expect(registry.all.map((tool) => tool.id).toSet(), hasLength(12));
    expect(registry.findById(intent.name),
        isA<SupplierPaymentsByFinancialAccountTool>());
    for (final id in _existingActionIds) {
      expect(registry.findById(id), isNotNull);
    }
  });

  test('metadata has only the approved read-only, confirmation-free contract',
      () {
    final tool = SupplierPaymentsByFinancialAccountTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_supplier_payments_by_account');
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.parameters.map((parameter) => parameter.id), [
      'financialAccountId',
      'startDate',
      'endDate',
      'supplierId',
    ]);
    expect(tool.parameters.take(3).every((parameter) => parameter.required),
        isTrue);
    expect(tool.parameters.last.required, isFalse);
  });

  test('authorized caller receives the exact immutable canonical report',
      () async {
    final report = _report();
    final reader = _Reader(report);
    final response =
        await _service(reader: reader, caller: _owner).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    expect(response.tables, isEmpty);
    expect(reader.calls, 1);
    expect(reader.financialAccountId, 'account-1');
    expect(reader.startDate, DateTime(2026, 7, 1));
    expect(reader.endDate, DateTime(2026, 7, 31));
    expect(reader.supplierId, 'supplier-1');
    final data = response.data! as SupplierPaymentsByFinancialAccountReport;
    expect(data.financialAccount.isActive, isFalse);
    expect(data.supplierIdFilter, 'supplier-1');
    expect(data.rowCount, 2);
    expect(data.totalAmountQirsh, 375);
    expect(data.rows.map((row) => row.paymentId), ['shared', 'shared']);
    expect(data.rows.first.isSupplierActive, isFalse);
    expect(data.rows.first.paymentMethod, isNull);
    expect(() => data.rows.add(data.rows.first), throwsUnsupportedError);
  });

  test('accepts an omitted supplier filter and preserves an empty report',
      () async {
    final empty = _report(rows: const [], supplierIdFilter: null);
    final reader = _Reader(empty);
    final response = await _service(reader: reader, caller: _owner).execute(
      const AiIntent(
        name: 'financial_supplier_payments_by_account',
        confidence: 1,
        parameters: {
          'financialAccountId': 'account-1',
          'startDate': '2026-07-01',
          'endDate': '2026-07-31',
        },
        executionMode: AiExecutionMode.readOnly,
      ),
    );

    expect(response.isSuccess, isTrue);
    expect(response.data, same(empty));
    expect(reader.supplierId, isNull);
    final data = response.data! as SupplierPaymentsByFinancialAccountReport;
    expect(data.rows, isEmpty);
    expect(data.rowCount, 0);
    expect(data.totalAmountQirsh, 0);
  });

  test(
      'rejects missing, unsupported, malformed, and invalid inputs before reader',
      () async {
    final invalidParameters = <Map<String, Object?>>[
      {},
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-01',
      },
      {
        'financialAccountId': '',
        'startDate': '2026-07-01',
        'endDate': '2026-07-31',
      },
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-7-01',
        'endDate': '2026-07-31',
      },
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-02-30',
        'endDate': '2026-07-31',
      },
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-31',
        'endDate': '2026-07-01',
      },
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-01',
        'endDate': '2026-07-31',
        'supplierId': ' ',
      },
      {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-01',
        'endDate': '2026-07-31',
        'paymentMethod': 'cash',
      },
    ];

    for (final parameters in invalidParameters) {
      final reader = _Reader(_report());
      final response = await _service(reader: reader, caller: _owner).execute(
        AiIntent(
          name: intent.name,
          confidence: 1,
          parameters: parameters,
          executionMode: AiExecutionMode.readOnly,
        ),
      );
      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(reader.calls, 0);
    }
  });

  test('wrong mode and denied permission fail before any protected read',
      () async {
    final modeReader = _Reader(_report());
    final modeResponse = await _service(reader: modeReader, caller: _owner)
        .execute(const AiIntent(
      name: 'financial_supplier_payments_by_account',
      confidence: 1,
      parameters: {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-01',
        'endDate': '2026-07-31',
      },
      executionMode: AiExecutionMode.execute,
    ));
    expect(modeResponse.status, AiResponseStatus.validationFailure);
    expect(modeReader.calls, 0);

    for (final caller in <AppUser?>[
      null,
      _owner.copyWith(isActive: false),
      _employee
    ]) {
      final reader = _Reader(_report());
      final response =
          await _service(reader: reader, caller: caller).execute(intent);
      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(reader.calls, 0);
    }
  });

  test('domain and unexpected errors use the existing safe failure response',
      () async {
    for (final reader in <SupplierPaymentsByFinancialAccountReportReader>[
      _FailingReader(StateError('supplier missing at C:\\private\\database')),
      _FailingReader(Exception('repository table supplier_payments')),
    ]) {
      final response =
          await _service(reader: reader, caller: _owner).execute(intent);
      expect(response.status, AiResponseStatus.failure);
      expect(response.messages,
          ['The requested operation could not be completed.']);
      expect(response.data, isNull);
      expect(response.messages.single, isNot(contains('C:\\')));
      expect(response.messages.single, isNot(contains('repository')));
    }
  });

  test('tool and reader contain no repository access or report transformation',
      () async {
    final toolSource = await File(
      'lib/features/ai_assistant/tools/supplier_payments_by_financial_account_tool.dart',
    ).readAsString();
    final readerSource = await File(
      'lib/features/ai_assistant/services/supplier_payments_by_financial_account_report_reader.dart',
    ).readAsString();
    final reportSource = await File(
      'lib/core/supplier_accounts/supplier_payments_by_financial_account_report.dart',
    ).readAsString();

    expect(
        toolSource, contains('SupplierPaymentsByFinancialAccountReportReader'));
    expect(toolSource, isNot(contains('Repository')));
    expect(toolSource, isNot(contains('.sort(')));
    expect(toolSource, isNot(contains('fold(')));
    expect(toolSource, isNot(contains('double')));
    expect(readerSource,
        contains('_service.supplierPaymentsByFinancialAccountReport('));
    expect(readerSource, isNot(contains('Repository')));
    for (final prohibited in [
      'phone',
      'address',
      'notes',
      'balance',
      'password'
    ]) {
      expect(reportSource.toLowerCase(), isNot(contains(prohibited)));
    }
  });
}

AiExecutionService _service({
  required SupplierPaymentsByFinancialAccountReportReader reader,
  required AppUser? caller,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        SupplierPaymentsByFinancialAccountTool(reader: reader, caller: caller),
      ]),
    );

SupplierPaymentsByFinancialAccountReport _report({
  List<SupplierPaymentsByFinancialAccountReportRow>? rows,
  String? supplierIdFilter = 'supplier-1',
}) =>
    SupplierPaymentsByFinancialAccountReport(
      financialAccount: const SupplierPaymentsByFinancialAccountReportAccount(
        id: 'account-1',
        name: 'Inactive bank account',
        type: FinancialAccountType.bank,
        isActive: false,
      ),
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 31),
      supplierIdFilter: supplierIdFilter,
      rows: rows ??
          [
            SupplierPaymentsByFinancialAccountReportRow(
              paymentId: 'shared',
              paymentDate: DateTime(2026, 7, 2),
              supplierId: 'supplier-1',
              supplierName: 'Inactive supplier',
              isSupplierActive: false,
              financialAccountId: 'account-1',
              paymentMethod: null,
              amountQirsh: 125,
            ),
            SupplierPaymentsByFinancialAccountReportRow(
              paymentId: 'shared',
              paymentDate: DateTime(2026, 7, 2),
              supplierId: 'supplier-1',
              supplierName: 'Inactive supplier',
              isSupplierActive: false,
              financialAccountId: 'account-1',
              paymentMethod: PaymentMethod.bankTransfer,
              amountQirsh: 250,
            ),
          ],
      totalAmountQirsh: rows?.isEmpty ?? false ? 0 : 375,
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

const _existingActionIds = [
  'inventory_attention',
  'financial_account_balances',
  'financial_account_statement',
  'financial_payment_method_summary',
  'financial_transfer_summary',
  'financial_advances_and_refunds_summary',
  'financial_closing_reconciliation_summary',
  'financial_inflows_summary',
  'financial_outflows_summary',
  'financial_expense_analysis',
  'financial_customer_collections_by_account',
];

final class _Reader implements SupplierPaymentsByFinancialAccountReportReader {
  _Reader(this.report);

  final SupplierPaymentsByFinancialAccountReport report;
  int calls = 0;
  String? financialAccountId;
  DateTime? startDate;
  DateTime? endDate;
  String? supplierId;

  @override
  Future<SupplierPaymentsByFinancialAccountReport>
      loadSupplierPaymentsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  }) async {
    calls++;
    this.financialAccountId = financialAccountId;
    this.startDate = startDate;
    this.endDate = endDate;
    this.supplierId = supplierId;
    return report;
  }
}

final class _FailingReader
    implements SupplierPaymentsByFinancialAccountReportReader {
  const _FailingReader(this.error);

  final Object error;

  @override
  Future<SupplierPaymentsByFinancialAccountReport>
      loadSupplierPaymentsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
  }) =>
          Future<SupplierPaymentsByFinancialAccountReport>.error(error);
}

final class _IdTool implements AiTool {
  const _IdTool(this.id);

  @override
  final String id;
  @override
  String get name => id;
  @override
  String get description => id;
  @override
  List<AiToolParameter> get parameters => const [];
  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async =>
      const AiToolResult();
}
