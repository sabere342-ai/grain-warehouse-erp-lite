import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collections_by_financial_account_report.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_customer_collections_by_account',
    confidence: 1,
    parameters: {
      'financialAccountId': 'account-1',
      'startDate': '2026-07-01',
      'endDate': '2026-07-31',
      'customerId': 'customer-1',
    },
    executionMode: AiExecutionMode.readOnly,
  );

  test('registers the exact BUILD-17 action once in a caller-supplied registry',
      () {
    final registry = AiToolRegistry([
      ..._existingActionIds.map(_IdTool.new),
      CustomerCollectionsByFinancialAccountTool(
        reader: _Reader(_report()),
        caller: _owner,
      ),
    ]);

    expect(registry.all, hasLength(11));
    expect(
      registry.all.map((tool) => tool.id).toSet(),
      hasLength(11),
    );
    expect(registry.findById(intent.name),
        isA<CustomerCollectionsByFinancialAccountTool>());
    for (final id in _existingActionIds) {
      expect(registry.findById(id), isNotNull);
    }
  });

  test('metadata has only the approved read-only, confirmation-free contract',
      () {
    final tool = CustomerCollectionsByFinancialAccountTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_customer_collections_by_account');
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.parameters.map((parameter) => parameter.id), [
      'financialAccountId',
      'startDate',
      'endDate',
      'customerId',
    ]);
    expect(tool.parameters.take(3).every((parameter) => parameter.required),
        isTrue);
    expect(tool.parameters.last.required, isFalse);
    expect(
        tool.parameters
            .every((parameter) => parameter.type == AiParameterType.string),
        isTrue);
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
    expect(reader.customerId, 'customer-1');
    final data = response.data! as CustomerCollectionsByFinancialAccountReport;
    expect(data.financialAccount.id, 'account-1');
    expect(data.financialAccount.isActive, isFalse);
    expect(data.customerIdFilter, 'customer-1');
    expect(data.rowCount, 2);
    expect(data.totalAmountQirsh, 375);
    expect(
        data.rows.map((row) => row.collectionId), ['same-day-a', 'same-day-b']);
    expect(data.rows.first.isCustomerActive, isFalse);
    expect(data.rows.first.paymentMethod, isNull);
  });

  test('accepts a null customer filter and passes it through unchanged',
      () async {
    final reader = _Reader(_report(customerIdFilter: null));
    final response = await _service(reader: reader, caller: _owner).execute(
      const AiIntent(
        name: 'financial_customer_collections_by_account',
        confidence: 1,
        parameters: {
          'financialAccountId': 'account-1',
          'startDate': '2026-07-01',
          'endDate': '2026-07-31',
          'customerId': null,
        },
        executionMode: AiExecutionMode.readOnly,
      ),
    );

    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(reader.customerId, isNull);
    expect((response.data! as CustomerCollectionsByFinancialAccountReport).rows,
        isNotEmpty);
  });

  test('preserves an authorized empty report without calculating values',
      () async {
    final report = _report(rows: const []);
    final response =
        await _service(reader: _Reader(report), caller: _owner).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    final data = response.data! as CustomerCollectionsByFinancialAccountReport;
    expect(data.rows, isEmpty);
    expect(data.rowCount, 0);
    expect(data.totalAmountQirsh, 0);
  });

  test('rejects unsupported, missing, and invalid inputs before the reader',
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
        'customerId': ' ',
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
    final wrongModeReader = _Reader(_report());
    final wrongMode = await _service(reader: wrongModeReader, caller: _owner)
        .execute(const AiIntent(
      name: 'financial_customer_collections_by_account',
      confidence: 1,
      parameters: {
        'financialAccountId': 'account-1',
        'startDate': '2026-07-01',
        'endDate': '2026-07-31',
      },
      executionMode: AiExecutionMode.execute,
    ));
    expect(wrongMode.status, AiResponseStatus.validationFailure);
    expect(wrongModeReader.calls, 0);

    for (final caller in <AppUser?>[
      null,
      _owner.copyWith(isActive: false),
      _employee
    ]) {
      final reader = _Reader(_report());
      final response =
          await _service(reader: reader, caller: caller).execute(intent);
      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.messages.single,
          'You are not authorized to view financial reports.');
      expect(response.data, isNull);
      expect(reader.calls, 0);
    }
  });

  test('canonical not-found and unexpected failures use the safe response',
      () async {
    for (final reader in <CustomerCollectionsByFinancialAccountReportReader>[
      _FailingReader(StateError('account missing at C:\\private\\database')),
      _FailingReader(StateError('customer missing at C:\\private\\database')),
      _FailingReader(Exception('repository table customer_collections')),
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
      'lib/features/ai_assistant/tools/customer_collections_by_financial_account_tool.dart',
    ).readAsString();
    final readerSource = await File(
      'lib/features/ai_assistant/services/customer_collections_by_financial_account_report_reader.dart',
    ).readAsString();
    final resultSource = await File(
      'lib/core/customer_accounts/customer_collections_by_financial_account_report.dart',
    ).readAsString();

    expect(toolSource,
        contains('CustomerCollectionsByFinancialAccountReportReader'));
    expect(toolSource, isNot(contains('Repository')));
    expect(toolSource, isNot(contains('.sort(')));
    expect(toolSource, isNot(contains('fold(')));
    expect(toolSource, isNot(contains('double')));
    expect(readerSource,
        contains('_service.customerCollectionsByFinancialAccountReport('));
    expect(readerSource, isNot(contains('Repository')));
    expect(resultSource, isNot(contains('phone')));
    expect(resultSource, isNot(contains('address')));
    expect(resultSource, isNot(contains('notes')));
    expect(resultSource, isNot(contains('balance')));
  });
}

AiExecutionService _service({
  required CustomerCollectionsByFinancialAccountReportReader reader,
  required AppUser? caller,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        CustomerCollectionsByFinancialAccountTool(
            reader: reader, caller: caller),
      ]),
    );

CustomerCollectionsByFinancialAccountReport _report({
  List<CustomerCollectionsByFinancialAccountReportRow>? rows,
  String? customerIdFilter = 'customer-1',
}) =>
    CustomerCollectionsByFinancialAccountReport(
      financialAccount:
          const CustomerCollectionsByFinancialAccountReportAccount(
        id: 'account-1',
        name: 'Inactive bank account',
        type: FinancialAccountType.bank,
        isActive: false,
      ),
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 31),
      customerIdFilter: customerIdFilter,
      rows: rows ??
          [
            CustomerCollectionsByFinancialAccountReportRow(
              collectionId: 'same-day-a',
              collectionDate: DateTime(2026, 7, 2),
              customerId: 'customer-1',
              customerName: 'Inactive customer',
              isCustomerActive: false,
              financialAccountId: 'account-1',
              paymentMethod: null,
              amountQirsh: 125,
            ),
            CustomerCollectionsByFinancialAccountReportRow(
              collectionId: 'same-day-b',
              collectionDate: DateTime(2026, 7, 2),
              customerId: 'customer-1',
              customerName: 'Inactive customer',
              isCustomerActive: false,
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
];

final class _Reader
    implements CustomerCollectionsByFinancialAccountReportReader {
  _Reader(this.report);

  final CustomerCollectionsByFinancialAccountReport report;
  int calls = 0;
  String? financialAccountId;
  DateTime? startDate;
  DateTime? endDate;
  String? customerId;

  @override
  Future<CustomerCollectionsByFinancialAccountReport>
      loadCustomerCollectionsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
  }) async {
    calls++;
    this.financialAccountId = financialAccountId;
    this.startDate = startDate;
    this.endDate = endDate;
    this.customerId = customerId;
    return report;
  }
}

final class _FailingReader
    implements CustomerCollectionsByFinancialAccountReportReader {
  const _FailingReader(this.error);

  final Object error;

  @override
  Future<CustomerCollectionsByFinancialAccountReport>
      loadCustomerCollectionsByFinancialAccountReport({
    required String financialAccountId,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
  }) =>
          Future<CustomerCollectionsByFinancialAccountReport>.error(error);
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
