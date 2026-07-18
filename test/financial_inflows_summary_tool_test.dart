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
    name: 'financial_inflows_summary',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-10 action exactly once', () {
    final registry = AiToolRegistry([
      FinancialInflowsSummaryTool(
        reader: _Reader(_report()),
        caller: _financialReportsViewer,
      ),
    ]);

    expect(
      registry.findById('financial_inflows_summary'),
      isA<FinancialInflowsSummaryTool>(),
    );
    expect(
      registry.all
          .where((tool) => tool.id == 'financial_inflows_summary')
          .length,
      1,
    );
  });

  test('metadata is strictly read-only and accepts exactly an empty object',
      () {
    final tool = FinancialInflowsSummaryTool(
      reader: _Reader(_report()),
      caller: _financialReportsViewer,
    );

    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
  });

  test('authorized financial-report viewer receives the exact report',
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
    final data = response.data! as FlowReport;
    expect(data.entries.map((entry) => entry.entryId), ['new', 'old']);
    expect(data.entries.first.amountQirsh, 101);
    expect(data.entries.first.isReversal, isFalse);
    expect(data.entries.last.amountQirsh, -7);
    expect(data.entries.last.isReversal, isTrue);
    expect(data.sourceBreakdown[FinancialAccountEntrySource.customerCollection],
        101);
    expect(data.totalQirsh, 94);
  });

  test('preserves an authorized empty canonical report', () async {
    final report = _report(empty: true);
    final response = await _service(
      reader: _Reader(report),
      caller: _financialReportsViewer,
    ).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    expect((response.data! as FlowReport).entries, isEmpty);
    expect((response.data! as FlowReport).totalQirsh, 0);
  });

  test('rejects every input key, including null values, before the reader',
      () async {
    for (final parameters in <Map<String, Object?>>[
      {'fromDate': null},
      {'toDate': null},
      {'accountId': 'bank'},
      {'anything': 1},
    ]) {
      final reader = _Reader(_report());
      final response = await _service(
        reader: reader,
        caller: _financialReportsViewer,
      ).execute(
        AiIntent(
          name: 'financial_inflows_summary',
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

  test('typed intent boundary rejects non-object input forms', () {
    for (final dynamic malformed in <dynamic>[null, [], 'report', 5, true]) {
      expect(
        () => AiIntent(
          name: 'financial_inflows_summary',
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
      name: 'financial_inflows_summary',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    ));

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('missing, inactive, and unauthorized callers fail before the reader',
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
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('reader failures use the existing safe AI failure response', () async {
    final response = await _service(
      reader: _FailingReader(),
      caller: _financialReportsViewer,
    ).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
      response.messages,
      ['The requested operation could not be completed.'],
    );
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
  });

  test('tool and reader delegate without repository access or report logic',
      () async {
    final toolSource = await File(
      'lib/features/ai_assistant/tools/financial_inflows_summary_tool.dart',
    ).readAsString();
    final readerSource = await File(
      'lib/features/ai_assistant/services/financial_account_balance_report_reader.dart',
    ).readAsString();

    expect(toolSource, contains('FinancialInflowsReportReader'));
    expect(toolSource, isNot(contains('Repository')));
    expect(toolSource, isNot(contains('AppRepositories')));
    expect(toolSource, isNot(contains('.sort(')));
    expect(readerSource, contains('_service.inflowsReport()'));
    expect(readerSource, isNot(contains('_repository')));
  });
}

AiExecutionService _service({
  required FinancialInflowsReportReader reader,
  required AppUser? caller,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialInflowsSummaryTool(
          reader: reader,
          caller: caller,
        ),
      ]),
    );

FlowReport _report({bool empty = false}) => FlowReport(
      fromDate: DateTime(2026, 7, 1),
      toDate: DateTime(2026, 7, 18, 12),
      entries: empty
          ? const []
          : [
              FlowReportEntry(
                entryId: 'new',
                timestamp: DateTime(2026, 7, 18, 9),
                accountId: 'cash',
                accountName: 'Cash',
                source: FinancialAccountEntrySource.customerCollection,
                referenceId: 'COL-2',
                description: null,
                amountQirsh: 101,
                direction: FinancialAccountEntryDirection.inflow,
                isReversal: false,
              ),
              FlowReportEntry(
                entryId: 'old',
                timestamp: DateTime(2026, 7, 2),
                accountId: 'bank',
                accountName: 'Bank',
                source: FinancialAccountEntrySource.cancellationReversal,
                referenceId: null,
                description: 'Canonical reversal',
                amountQirsh: -7,
                direction: FinancialAccountEntryDirection.inflow,
                isReversal: true,
              ),
            ],
      totalQirsh: empty ? 0 : 94,
      sourceBreakdown: empty
          ? const {}
          : const {
              FinancialAccountEntrySource.customerCollection: 101,
              FinancialAccountEntrySource.cancellationReversal: -7,
            },
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

final class _Reader implements FinancialInflowsReportReader {
  _Reader(this.report);

  final FlowReport report;
  int calls = 0;

  @override
  Future<FlowReport> loadFinancialInflowsReport() async {
    calls++;
    return report;
  }
}

final class _FailingReader implements FinancialInflowsReportReader {
  @override
  Future<FlowReport> loadFinancialInflowsReport() =>
      Future<FlowReport>.error(StateError('storage details'));
}
