import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_transfer_summary',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-06 action exactly once', () {
    final registry = AiToolRegistry([
      InventoryAttentionTool(service: _InventoryReader()),
      FinancialTransferSummaryTool(reader: _Reader(_report()), caller: _owner),
    ]);

    final tool = registry.findById('financial_transfer_summary')!;
    expect(tool, isA<FinancialTransferSummaryTool>());
    expect(
      registry.all
          .where((item) => item.id == 'financial_transfer_summary')
          .length,
      1,
    );
  });

  test('metadata is strictly read-only and has no mutation claim', () {
    final tool = FinancialTransferSummaryTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.id, 'financial_transfer_summary');
    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.description.toLowerCase(), isNot(contains('create')));
    expect(tool.description.toLowerCase(), isNot(contains('edit')));
    expect(tool.description.toLowerCase(), isNot(contains('reverse')));
  });

  test('passes through canonical rows, total, ordering, and nullable fields',
      () async {
    final report = _report();
    final reader = _Reader(report);
    final response = await _service(reader: reader).execute(intent);

    final data = response.data! as FinancialTransferSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(data.fromDate, report.fromDate);
    expect(data.toDate, report.toDate);
    expect(data.rows.map((row) => row.transferId),
        ['transfer-new', 'transfer-zero']);
    expect(data.rows.first.displayNumber, 'TR-002');
    expect(data.rows.first.sourceAccountName, 'Bank A');
    expect(data.rows.first.destinationAccountName, 'Treasury B');
    expect(data.rows.first.amountQirsh, 101);
    expect(data.rows.first.isReversal, isTrue);
    expect(data.rows.first.isReversed, isFalse);
    expect(data.rows.first.reversalDisplayNumber, 'TR-003');
    expect(data.rows.first.reversalDate, DateTime(2026, 1, 21));
    expect(data.rows.last.amountQirsh, 0);
    expect(data.rows.last.reference, isNull);
    expect(data.rows.last.note, isNull);
    expect(data.rows.last.reversalDisplayNumber, isNull);
    expect(data.rows.last.createdByUserId, isNull);
    expect(data.totalAmountQirsh, 101);
    expect(data.isEmpty, isFalse);
    expect(() => data.rows.add(data.rows.first), throwsUnsupportedError);
  });

  test('keeps an authorized empty canonical report immutable', () async {
    final response = await _service(reader: _Reader(_report(rows: const [])))
        .execute(intent);

    final data = response.data! as FinancialTransferSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(data.rows, isEmpty);
    expect(data.totalAmountQirsh, 0);
    expect(data.isEmpty, isTrue);
    expect(
      () => data.rows.add(
        FinancialTransferSummaryRow(
          transferId: 'unused',
          displayNumber: 'unused',
          effectiveDate: DateTime(2026),
          sourceAccountName: 'unused',
          destinationAccountName: 'unused',
          amountQirsh: 0,
          isReversal: false,
          isReversed: false,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('rejects every input key, including a null-valued key', () async {
    final invalidParameters = <Map<String, Object?>>[
      {'unknown': true},
      {'fromDate': null},
      {'accountId': 'account-1'},
      {'reversalFilter': 'original'},
    ];

    for (final parameters in invalidParameters) {
      final reader = _Reader(_report());
      final response = await _service(reader: reader).execute(
        AiIntent(
          name: 'financial_transfer_summary',
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

  test('the typed intent boundary rejects non-object input forms', () {
    for (final dynamic malformed in <dynamic>[null, [], 'transfer', 5, true]) {
      expect(
        () => AiIntent(
          name: 'financial_transfer_summary',
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
    final response = await _service(reader: reader).execute(const AiIntent(
      name: 'financial_transfer_summary',
      confidence: 1,
      parameters: {},
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
      final reader = _Reader(_report());
      final response = await AiExecutionService(
        registry: AiToolRegistry([
          FinancialTransferSummaryTool(reader: reader, caller: caller),
        ]),
      ).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('reader failures become the existing safe AI failure response',
      () async {
    final response = await _service(reader: _FailingReader()).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
  });

  test('tool depends only on the injected transfer report reader', () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_transfer_summary_tool.dart',
    ).readAsString();
    expect(source, contains('FinancialTransferReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
  });
}

AiExecutionService _service({required FinancialTransferReportReader reader}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialTransferSummaryTool(reader: reader, caller: _owner),
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

TransferReport _report({List<TransferReportRow>? rows}) {
  final reportRows = rows ??
      [
        TransferReportRow(
          transferId: 'transfer-new',
          displayNumber: 'TR-002',
          effectiveDate: DateTime(2026, 1, 20),
          sourceAccountName: 'Bank A',
          destinationAccountName: 'Treasury B',
          amountQirsh: 101,
          reference: 'bank move',
          note: 'canonical reversal',
          isReversal: true,
          isReversed: false,
          reversalDisplayNumber: 'TR-003',
          reversalDate: DateTime(2026, 1, 21),
          reversalReason: 'correction',
          createdByUserId: 'owner',
        ),
        TransferReportRow(
          transferId: 'transfer-zero',
          displayNumber: 'TR-001',
          effectiveDate: DateTime(2026, 1, 5),
          sourceAccountName: 'Treasury B',
          destinationAccountName: 'Bank A',
          amountQirsh: 0,
          isReversal: false,
          isReversed: false,
        ),
      ];
  return TransferReport(
    fromDate: DateTime(2026, 1),
    toDate: DateTime(2026, 1, 31),
    rows: reportRows,
    totalAmountQirsh: reportRows.isEmpty ? 0 : 101,
  );
}

final class _Reader implements FinancialTransferReportReader {
  _Reader(this.report);

  final TransferReport report;
  int calls = 0;

  @override
  Future<TransferReport> loadTransferReport() async {
    calls++;
    return report;
  }
}

final class _FailingReader implements FinancialTransferReportReader {
  @override
  Future<TransferReport> loadTransferReport() =>
      Future<TransferReport>.error(StateError('storage details'));
}

final class _InventoryReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() async => const [];
}
