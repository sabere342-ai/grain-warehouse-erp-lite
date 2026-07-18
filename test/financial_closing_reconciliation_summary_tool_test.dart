import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const intent = AiIntent(
    name: 'financial_closing_reconciliation_summary',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-08 action exactly once', () {
    final registry = AiToolRegistry([
      FinancialClosingReconciliationSummaryTool(
        reader: _Reader(_report()),
        caller: _owner,
      ),
    ]);

    expect(
      registry.findById('financial_closing_reconciliation_summary'),
      isA<FinancialClosingReconciliationSummaryTool>(),
    );
    expect(
      registry.all
          .where(
            (tool) => tool.id == 'financial_closing_reconciliation_summary',
          )
          .length,
      1,
    );
  });

  test('metadata is strictly read-only and has no confirmation', () {
    final tool = FinancialClosingReconciliationSummaryTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
  });

  test('owner receives the exact canonical report without projection',
      () async {
    final report = _report();
    final reader = _Reader(report);
    final response =
        await _service(reader: reader, caller: _owner).execute(intent);

    expect(response.isSuccess, isTrue);
    expect(response.data, same(report));
    expect(reader.calls, 1);
    expect(response.tables, isEmpty);
    final data = response.data! as FinancialClosingReconciliationReport;
    expect(data.closings.map((closing) => closing.closingId), ['new', 'old']);
    expect(data.closings.first.accountRows.map((row) => row.accountName), [
      'Treasury',
      'Inactive bank',
    ]);
    expect(data.closings.first.accountRows.first.expectedBalanceQirsh, 100);
    expect(data.closings.first.accountRows.first.actualBalanceQirsh, 100);
    expect(data.closings.first.accountRows.last.differenceQirsh, -20);
    expect(data.closings.first.totalDifferenceQirsh, -20);
    expect(data.closings.first.isOpen, isTrue);
    expect(data.closings.first.reopenedAt, DateTime(2026, 7, 3));
    expect(data.closings.first.reopenedByUserId, 'owner');
    expect(data.closings.first.reopenReason, 'Documented correction');
    expect(data.closings.last.note, isNull);
  });

  test('preserves an authorized immutable empty report', () async {
    final response = await _service(
      reader: _Reader(_report(empty: true)),
      caller: _owner,
    ).execute(intent);

    final data = response.data! as FinancialClosingReconciliationReport;
    expect(response.isSuccess, isTrue);
    expect(data.closings, isEmpty);
    expect(data.isEmpty, isTrue);
  });

  test('rejects every input key including null values before the reader',
      () async {
    for (final parameters in <Map<String, Object?>>[
      {'periodId': null},
      {'accountId': null},
      {'date': null},
      {'anything': 1},
    ]) {
      final reader = _Reader(_report());
      final response = await _service(reader: reader, caller: _owner).execute(
        AiIntent(
          name: 'financial_closing_reconciliation_summary',
          confidence: 1,
          parameters: parameters,
          executionMode: AiExecutionMode.readOnly,
        ),
      );

      expect(response.status, AiResponseStatus.validationFailure);
      expect(reader.calls, 0);
    }
  });

  test('wrong execution mode prevents report access', () async {
    final reader = _Reader(_report());
    final response = await _service(reader: reader, caller: _owner).execute(
      const AiIntent(
        name: 'financial_closing_reconciliation_summary',
        confidence: 1,
        parameters: {},
        executionMode: AiExecutionMode.execute,
      ),
    );

    expect(response.status, AiResponseStatus.validationFailure);
    expect(reader.calls, 0);
  });

  test('missing, inactive, and non-owner callers fail before the reader',
      () async {
    for (final caller in <AppUser?>[
      null,
      _owner.copyWith(isActive: false),
      _employee,
      _nonOwnerFinancialReportsViewer,
    ]) {
      final reader = _Reader(_report());
      final response =
          await _service(reader: reader, caller: caller).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(reader.calls, 0);
    }
  });

  test('reader failures become the existing safe AI failure', () async {
    final response = await _service(
      reader: _FailingReader(),
      caller: _owner,
    ).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
      response.messages,
      ['The requested operation could not be completed.'],
    );
  });

  test('tool has no repository dependency or financial calculations', () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_closing_reconciliation_summary_tool.dart',
    ).readAsString();

    expect(source, contains('FinancialClosingReconciliationReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
    expect(source, isNot(contains('double')));
  });
}

AiExecutionService _service({
  required FinancialClosingReconciliationReportReader reader,
  required AppUser? caller,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialClosingReconciliationSummaryTool(
            reader: reader, caller: caller),
      ]),
    );

FinancialClosingReconciliationReport _report({bool empty = false}) {
  if (empty) {
    return FinancialClosingReconciliationReport(closings: const []);
  }
  return FinancialClosingReconciliationReport(
    closings: [
      FinancialClosingReconciliationSummary(
        closingId: 'new',
        kind: FinancialClosingKind.daily,
        fromDate: DateTime(2026, 7, 2),
        toDate: DateTime(2026, 7, 2),
        createdAt: DateTime(2026, 7, 2, 18),
        createdByUserId: 'owner',
        isOpen: true,
        reopenedAt: DateTime(2026, 7, 3),
        reopenedByUserId: 'owner',
        reopenReason: 'Documented correction',
        totalDifferenceQirsh: -20,
        accountRows: const [
          FinancialClosingReconciliationAccountRow(
            accountId: 'treasury',
            accountName: 'Treasury',
            accountType: FinancialAccountType.treasury,
            isAccountActive: true,
            expectedBalanceQirsh: 100,
            actualBalanceQirsh: 100,
            differenceQirsh: 0,
          ),
          FinancialClosingReconciliationAccountRow(
            accountId: 'bank',
            accountName: 'Inactive bank',
            accountType: FinancialAccountType.bank,
            isAccountActive: false,
            expectedBalanceQirsh: 50,
            actualBalanceQirsh: 30,
            differenceQirsh: -20,
          ),
        ],
      ),
      FinancialClosingReconciliationSummary(
        closingId: 'old',
        kind: FinancialClosingKind.period,
        fromDate: DateTime(2026, 7, 1),
        toDate: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1, 18),
        createdByUserId: 'owner',
        note: null,
        isOpen: false,
        totalDifferenceQirsh: 0,
        accountRows: const [],
      ),
    ],
  );
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

final _nonOwnerFinancialReportsViewer = _NonOwnerFinancialReportsViewer(
  id: 'viewer',
  name: 'Financial viewer',
  phone: '01000000002',
  role: UserRole.employee,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final class _NonOwnerFinancialReportsViewer extends AppUser {
  const _NonOwnerFinancialReportsViewer({
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

final class _Reader implements FinancialClosingReconciliationReportReader {
  _Reader(this.report);

  final FinancialClosingReconciliationReport report;
  int calls = 0;

  @override
  Future<FinancialClosingReconciliationReport>
      loadClosingReconciliationReport() async {
    calls++;
    return report;
  }
}

final class _FailingReader
    implements FinancialClosingReconciliationReportReader {
  @override
  Future<FinancialClosingReconciliationReport>
      loadClosingReconciliationReport() =>
          Future<FinancialClosingReconciliationReport>.error(
            StateError('storage details'),
          );
}
