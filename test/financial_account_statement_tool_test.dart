import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_account_statement',
    confidence: 1,
    parameters: {'financialAccountId': 'account-1'},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-04 action exactly once', () {
    final registry = AiToolRegistry([
      InventoryAttentionTool(service: _InventoryReader()),
      FinancialAccountBalancesTool(reader: _BalanceReader(), caller: _owner),
      FinancialAccountStatementTool(
          reader: _StatementReader(_report()), caller: _owner),
    ]);

    expect(registry.findById('financial_account_statement'), isNotNull);
    expect(
      registry.all
          .where((tool) => tool.id == 'financial_account_statement')
          .length,
      1,
    );
  });

  test('metadata is read-only and exposes exactly one required identifier', () {
    final tool = FinancialAccountStatementTool(
      reader: _StatementReader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_account_statement');
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.parameters, hasLength(1));
    expect(tool.parameters.single.id, 'financialAccountId');
    expect(tool.parameters.single.type, AiParameterType.string);
    expect(tool.parameters.single.required, isTrue);
  });

  test('maps the canonical statement without changing order or qirsh values',
      () async {
    final reader = _StatementReader(_report());
    final response = await _service(reader: reader).execute(intent);

    final data = response.data! as FinancialAccountStatementResult;
    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(reader.accountIds, ['account-1']);
    expect(data.accountId, 'account-1');
    expect(data.accountName, 'Dormant bank account');
    expect(data.accountType, FinancialAccountType.bank);
    expect(data.isActive, isFalse);
    expect(data.openingBalanceQirsh, 101);
    expect(data.closingBalanceQirsh, 99);
    expect(
        data.entries.map((entry) => entry.entryId), ['later-id', 'earlier-id']);
    expect(data.entries.first.amountQirsh, 33);
    expect(data.entries.first.runningBalanceQirsh, 134);
    expect(
        data.entries.first.sourceType, FinancialAccountEntrySource.salePayment);
    expect(data.entries.first.paymentMethod, PaymentMethod.cash);
    expect(data.entries.last.reversalOf, 'original-entry');
    expect(data.entries.last.note, 'reversal note');
    expect(data.isEmpty, isFalse);
    expect(
      () => data.entries.add(data.entries.first),
      throwsUnsupportedError,
    );
  });

  test('accepts an inactive existing account when the canonical report does',
      () async {
    final response =
        await _service(reader: _StatementReader(_report())).execute(intent);

    final data = response.data! as FinancialAccountStatementResult;
    expect(response.isSuccess, isTrue);
    expect(data.isActive, isFalse);
  });

  test('maps an authorized empty statement without fabricating totals',
      () async {
    final response =
        await _service(reader: _StatementReader(_report(lines: const [])))
            .execute(intent);

    final data = response.data! as FinancialAccountStatementResult;
    expect(response.isSuccess, isTrue);
    expect(data.entries, isEmpty);
    expect(data.openingBalanceQirsh, 0);
    expect(data.closingBalanceQirsh, 0);
    expect(data.isEmpty, isTrue);
  });

  test('rejects missing, extra, empty, whitespace, and wrong-type input early',
      () async {
    final invalidParameters = <Map<String, Object?>>[
      {},
      {'financialAccountId': 'account-1', 'unexpected': true},
      {'financialAccountId': ''},
      {'financialAccountId': '   '},
      {'financialAccountId': 42},
      {'financialAccountId': null},
    ];

    for (final parameters in invalidParameters) {
      final reader = _StatementReader(_report());
      final response = await _service(reader: reader).execute(
        AiIntent(
          name: 'financial_account_statement',
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

  test('the typed intent contract rejects non-object parameter input', () {
    final dynamic malformed = <Object?, Object?>{1: 'unexpected'};
    expect(
      () => AiIntent(
        name: 'financial_account_statement',
        confidence: 1,
        parameters: malformed,
        executionMode: AiExecutionMode.readOnly,
      ),
      throwsA(isA<TypeError>()),
    );
  });

  test('wrong execution mode prevents statement access', () async {
    final reader = _StatementReader(_report());
    final response = await _service(reader: reader).execute(const AiIntent(
      name: 'financial_account_statement',
      confidence: 1,
      parameters: {'financialAccountId': 'account-1'},
      executionMode: AiExecutionMode.execute,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('missing, inactive, and unauthorized callers fail closed before reads',
      () async {
    for (final caller in <AppUser?>[
      null,
      _owner.copyWith(isActive: false),
      _employee
    ]) {
      final reader = _StatementReader(_report());
      final response = await AiExecutionService(
        registry: AiToolRegistry([
          FinancialAccountStatementTool(reader: reader, caller: caller),
        ]),
      ).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('unknown account reader failures become safe action failures', () async {
    final response =
        await _service(reader: _UnknownAccountReader()).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
  });

  test('tool source relies on the injected report reader, not repositories',
      () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_account_statement_tool.dart',
    ).readAsString();
    expect(source, contains('FinancialAccountStatementReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
  });
}

AiExecutionService _service({
  required FinancialAccountStatementReportReader reader,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountStatementTool(reader: reader, caller: _owner),
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

AccountStatementReport _report({List<AccountStatementReportLine>? lines}) {
  final reportLines = lines ??
      [
        AccountStatementReportLine(
          entry: _entry(
            id: 'later-id',
            amountQirsh: 33,
            effectiveDate: DateTime(2026, 1, 10),
            paymentMethod: PaymentMethod.cash,
          ),
          runningBalanceQirsh: 134,
        ),
        AccountStatementReportLine(
          entry: _entry(
            id: 'earlier-id',
            amountQirsh: 35,
            effectiveDate: DateTime(2026, 1, 5),
            direction: FinancialAccountEntryDirection.outflow,
            sourceType: FinancialAccountEntrySource.cancellationReversal,
            reversalOf: 'original-entry',
            note: 'reversal note',
          ),
          runningBalanceQirsh: 99,
        ),
      ];
  return AccountStatementReport(
    account: FinancialAccount(
      id: 'account-1',
      name: 'Dormant bank account',
      type: FinancialAccountType.bank,
      isActive: false,
      createdByUserId: 'owner',
      createdAt: DateTime(2026),
    ),
    fromDate: DateTime(2026, 1),
    toDate: DateTime(2026, 1, 31),
    lines: reportLines,
    openingBalanceQirsh: reportLines.isEmpty ? 0 : 101,
    closingBalanceQirsh: reportLines.isEmpty ? 0 : 99,
  );
}

FinancialAccountEntry _entry({
  required String id,
  required int amountQirsh,
  required DateTime effectiveDate,
  FinancialAccountEntryDirection direction =
      FinancialAccountEntryDirection.inflow,
  FinancialAccountEntrySource sourceType =
      FinancialAccountEntrySource.salePayment,
  String? reversalOf,
  String? note,
  PaymentMethod? paymentMethod,
}) =>
    FinancialAccountEntry(
      id: id,
      accountId: 'account-1',
      direction: direction,
      amountQirsh: amountQirsh,
      sourceType: sourceType,
      sourceDocumentId: 'source-$id',
      sourceDocumentNumber: 'DOC-$id',
      effectiveDate: effectiveDate,
      createdAt: DateTime(2026),
      createdByUserId: 'owner',
      reference: 'ref-$id',
      note: note,
      reversalOf: reversalOf,
      paymentMethod: paymentMethod,
    );

final class _StatementReader implements FinancialAccountStatementReportReader {
  _StatementReader(this.report);

  final AccountStatementReport report;
  final List<String> accountIds = [];
  int calls = 0;

  @override
  Future<AccountStatementReport> loadAccountStatementReport({
    required String financialAccountId,
  }) async {
    calls++;
    accountIds.add(financialAccountId);
    return report;
  }
}

final class _UnknownAccountReader
    implements FinancialAccountStatementReportReader {
  @override
  Future<AccountStatementReport> loadAccountStatementReport({
    required String financialAccountId,
  }) =>
      Future<AccountStatementReport>.error(
          StateError('account does not exist'));
}

final class _BalanceReader implements FinancialAccountBalanceReportReader {
  @override
  Future<AccountBalanceReport> loadAccountBalanceReport() =>
      Future<AccountBalanceReport>.error(UnimplementedError());
}

final class _InventoryReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() async => const [];
}
