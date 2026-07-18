import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_account_balances',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers BUILD-01, BUILD-02, and BUILD-03 tools once', () {
    final registry = AiToolRegistry([
      InventoryAttentionTool(service: _InventoryReader()),
      FinancialAccountBalancesTool(reader: _Reader(_report()), caller: _owner),
    ]);

    expect(registry.findById('inventory_attention'), isNotNull);
    expect(registry.findById('financial_account_balances'), isNotNull);
    expect(
      registry.all
          .where((tool) => tool.id == 'financial_account_balances')
          .length,
      1,
    );
  });

  test('metadata is canonical, read-only, and needs no confirmation', () {
    final tool = FinancialAccountBalancesTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_account_balances');
    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
  });

  test('maps the authoritative report without changing its ordering or money',
      () async {
    final reader = _Reader(_report());
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(reader: reader, caller: _owner),
      ]),
    ).execute(intent);

    final data = response.data! as FinancialAccountBalancesResult;
    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(data.accounts.map((item) => item.accountId), ['bank', 'cash']);
    expect(data.accounts.first.accountType, FinancialAccountType.bank);
    expect(data.accounts.first.isActive, isFalse);
    expect(data.accounts.first.openingBalanceQirsh, 101);
    expect(data.accounts.first.totalInflowsQirsh, 33);
    expect(data.accounts.first.totalOutflowsQirsh, 7);
    expect(data.accounts.first.currentBalanceQirsh, 127);
    expect(data.totals.currentBalanceQirsh, 177);
    expect(data.isEmpty, isFalse);
    expect(
        () => data.accounts.add(data.accounts.first), throwsUnsupportedError);
  });

  test('returns an authorized immutable empty report', () async {
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(
          reader: _Reader(_report(rows: const [])),
          caller: _owner,
        ),
      ]),
    ).execute(intent);

    final data = response.data! as FinancialAccountBalancesResult;
    expect(response.isSuccess, isTrue);
    expect(data.accounts, isEmpty);
    expect(data.totals.currentBalanceQirsh, 0);
    expect(data.isEmpty, isTrue);
  });

  test('rejects unexpected input before the report boundary executes',
      () async {
    final reader = _Reader(_report());
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(reader: reader, caller: _owner),
      ]),
    ).execute(const AiIntent(
      name: 'financial_account_balances',
      confidence: 1,
      parameters: {'accountId': 'cash'},
      executionMode: AiExecutionMode.readOnly,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('the typed intent contract rejects malformed non-string-key inputs', () {
    final dynamic malformed = <Object?, Object?>{1: 'unexpected'};
    expect(
      () => AiIntent(
        name: 'financial_account_balances',
        confidence: 1,
        parameters: malformed,
        executionMode: AiExecutionMode.readOnly,
      ),
      throwsA(isA<TypeError>()),
    );
  });

  test('wrong execution mode prevents report execution', () async {
    final reader = _Reader(_report());
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(reader: reader, caller: _owner),
      ]),
    ).execute(const AiIntent(
      name: 'financial_account_balances',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('unauthorized callers fail closed without financial data', () async {
    final reader = _Reader(_report());
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(reader: reader, caller: _employee),
      ]),
    ).execute(intent);

    expect(response.status, AiResponseStatus.validationFailure);
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
    expect(reader.calls, 0);
  });

  test('missing or inactive callers fail closed', () async {
    final inactiveOwner = _owner.copyWith(isActive: false);
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(
          reader: _Reader(_report()),
          caller: inactiveOwner,
        ),
      ]),
    ).execute(intent);

    expect(response.status, AiResponseStatus.validationFailure);
    expect(response.data, isNull);
  });

  test('report failures are converted to safe AI failures', () async {
    final response = await AiExecutionService(
      registry: AiToolRegistry([
        FinancialAccountBalancesTool(reader: _FailingReader(), caller: _owner),
      ]),
    ).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
  });

  test('tool source uses only the injected report reader and no repository',
      () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_account_balances_tool.dart',
    ).readAsString();
    expect(source, contains('FinancialAccountBalanceReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
  });
}

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

AccountBalanceReport _report({List<AccountBalanceReportRow>? rows}) {
  final reportRows = rows ??
      [
        AccountBalanceReportRow(
          account: _account('bank', 'Bank', FinancialAccountType.bank,
              isActive: false),
          openingBalanceQirsh: 101,
          totalInflowsQirsh: 33,
          totalOutflowsQirsh: 7,
          entryCount: 2,
        ),
        AccountBalanceReportRow(
          account: _account('cash', 'Cash', FinancialAccountType.treasury),
          openingBalanceQirsh: 50,
          totalInflowsQirsh: 0,
          totalOutflowsQirsh: 0,
          entryCount: 0,
        ),
      ];
  return AccountBalanceReport(
    fromDate: DateTime(2026, 1),
    toDate: DateTime(2026, 1, 31),
    rows: reportRows,
    totalOpeningQirsh: reportRows.isEmpty ? 0 : 151,
    totalInflowsQirsh: reportRows.isEmpty ? 0 : 33,
    totalOutflowsQirsh: reportRows.isEmpty ? 0 : 7,
    totalClosingQirsh: reportRows.isEmpty ? 0 : 177,
  );
}

FinancialAccount _account(
  String id,
  String name,
  FinancialAccountType type, {
  bool isActive = true,
}) =>
    FinancialAccount(
      id: id,
      name: name,
      type: type,
      isActive: isActive,
      createdByUserId: 'owner',
      createdAt: DateTime(2026),
    );

final class _Reader implements FinancialAccountBalanceReportReader {
  _Reader(this.report);

  final AccountBalanceReport report;
  int calls = 0;

  @override
  Future<AccountBalanceReport> loadAccountBalanceReport() async {
    calls++;
    return report;
  }
}

final class _FailingReader implements FinancialAccountBalanceReportReader {
  @override
  Future<AccountBalanceReport> loadAccountBalanceReport() =>
      Future<AccountBalanceReport>.error(StateError('database details'));
}

final class _InventoryReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() async => const [];
}
