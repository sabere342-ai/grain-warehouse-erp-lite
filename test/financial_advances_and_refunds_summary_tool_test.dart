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
    name: 'financial_advances_and_refunds_summary',
    confidence: 1,
    parameters: {},
    executionMode: AiExecutionMode.readOnly,
  );

  test('registry discovers the BUILD-07 action exactly once', () {
    final registry = AiToolRegistry([
      InventoryAttentionTool(service: _InventoryReader()),
      FinancialAdvancesAndRefundsSummaryTool(
        reader: _Reader(_report()),
        caller: _owner,
      ),
    ]);

    final tool = registry.findById('financial_advances_and_refunds_summary')!;
    expect(tool, isA<FinancialAdvancesAndRefundsSummaryTool>());
    expect(
      registry.all
          .where(
            (item) => item.id == 'financial_advances_and_refunds_summary',
          )
          .length,
      1,
    );
  });

  test('metadata is strictly read-only and does not claim mutation', () {
    final tool = FinancialAdvancesAndRefundsSummaryTool(
      reader: _Reader(_report()),
      caller: _owner,
    );

    expect(tool.parameters, isEmpty);
    expect(tool.requiredExecutionMode, AiExecutionMode.readOnly);
    expect(tool.requiresConfirmation, isFalse);
    expect(tool.description.toLowerCase(), isNot(contains('create')));
    expect(tool.description.toLowerCase(), isNot(contains('edit')));
    expect(tool.description.toLowerCase(), isNot(contains('reverse')));
  });

  test('maps canonical rows, summaries, totals, ordering, and nulls', () async {
    final report = _report();
    final reader = _Reader(report);
    final response = await _service(reader: reader).execute(intent);

    final data = response.data! as FinancialAdvancesAndRefundsSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(reader.calls, 1);
    expect(data.fromDate, report.fromDate);
    expect(data.toDate, report.toDate);
    expect(data.details.map((detail) => detail.entryId), [
      'supplier-row',
      'customer-row',
    ]);
    expect(data.details.first.partyType, AdvancesAndRefundsPartyType.supplier);
    expect(data.details.first.accountName, 'Bank account');
    expect(data.details.first.entityId, isNull);
    expect(data.details.first.entityName, 'Canonical unresolved supplier');
    expect(data.details.first.amountQirsh, 101);
    expect(data.details.first.signedCashEffectQirsh, 101);
    expect(data.details.first.reference, isNull);
    expect(data.details.first.reversalOfEntryId, 'original-entry');
    expect(data.details.last.partyType, AdvancesAndRefundsPartyType.customer);
    expect(data.details.last.amountQirsh, 33);
    expect(data.details.last.signedCashEffectQirsh, -33);
    expect(data.accountSummaries.single.accountId, 'bank');
    expect(data.accountSummaries.single.accountType, FinancialAccountType.bank);
    expect(data.accountSummaries.single.customerNetRefundOutflowQirsh, 26);
    expect(data.accountSummaries.single.supplierNetRefundInflowQirsh, 94);
    expect(data.customerSummaries.single.entityName, 'Canonical customer');
    expect(data.supplierSummaries.single.entityId, isNull);
    expect(data.totalCustomerGrossRefundOutflowQirsh, 33);
    expect(data.totalCustomerRefundReversalsQirsh, 7);
    expect(data.totalCustomerNetRefundOutflowQirsh, 26);
    expect(data.totalSupplierGrossRefundInflowQirsh, 101);
    expect(data.totalSupplierRefundReversalsQirsh, 7);
    expect(data.totalSupplierNetRefundInflowQirsh, 94);
    expect(data.signedGrandCashEffectQirsh, 68);
    expect(data.isEmpty, isFalse);
    expect(() => data.details.add(data.details.first), throwsUnsupportedError);
    expect(
      () => data.accountSummaries.add(data.accountSummaries.first),
      throwsUnsupportedError,
    );
    expect(
      () => data.customerSummaries.add(data.customerSummaries.first),
      throwsUnsupportedError,
    );
    expect(
      () => data.supplierSummaries.add(data.supplierSummaries.first),
      throwsUnsupportedError,
    );
  });

  test('preserves an authorized empty canonical report immutably', () async {
    final response =
        await _service(reader: _Reader(_report(empty: true))).execute(intent);

    final data = response.data! as FinancialAdvancesAndRefundsSummaryResult;
    expect(response.isSuccess, isTrue);
    expect(data.details, isEmpty);
    expect(data.accountSummaries, isEmpty);
    expect(data.customerSummaries, isEmpty);
    expect(data.supplierSummaries, isEmpty);
    expect(data.signedGrandCashEffectQirsh, 0);
    expect(data.isEmpty, isTrue);
  });

  test('rejects every input key, including a null-valued key', () async {
    final invalidParameters = <Map<String, Object?>>[
      {'unknown': true},
      {'fromDate': null},
      {'accountId': 'bank'},
      {'partyType': 'customer'},
      {'entityId': 'customer-1'},
    ];

    for (final parameters in invalidParameters) {
      final reader = _Reader(_report());
      final response = await _service(reader: reader).execute(
        AiIntent(
          name: 'financial_advances_and_refunds_summary',
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
    for (final dynamic malformed in <dynamic>[null, [], 'report', 5, true]) {
      expect(
        () => AiIntent(
          name: 'financial_advances_and_refunds_summary',
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
      name: 'financial_advances_and_refunds_summary',
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
      final reader = _Reader(_report());
      final response = await AiExecutionService(
        registry: AiToolRegistry([
          FinancialAdvancesAndRefundsSummaryTool(
            reader: reader,
            caller: caller,
          ),
        ]),
      ).execute(intent);

      expect(response.status, AiResponseStatus.validationFailure);
      expect(response.data, isNull);
      expect(response.tables, isEmpty);
      expect(reader.calls, 0);
    }
  });

  test('reader failures use the existing safe AI failure response', () async {
    final response = await _service(reader: _FailingReader()).execute(intent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
    expect(response.data, isNull);
    expect(response.tables, isEmpty);
  });

  test('tool depends only on the injected canonical report reader', () async {
    final source = await File(
      'lib/features/ai_assistant/tools/financial_advances_and_refunds_summary_tool.dart',
    ).readAsString();
    expect(source, contains('FinancialAdvancesAndRefundsReportReader'));
    expect(source, isNot(contains('Repository')));
    expect(source, isNot(contains('AppRepositories')));
  });
}

AiExecutionService _service({
  required FinancialAdvancesAndRefundsReportReader reader,
}) =>
    AiExecutionService(
      registry: AiToolRegistry([
        FinancialAdvancesAndRefundsSummaryTool(reader: reader, caller: _owner),
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

AdvancesAndRefundsReport _report({bool empty = false}) {
  if (empty) {
    return AdvancesAndRefundsReport(
      fromDate: DateTime(2026, 1),
      toDate: DateTime(2026, 1, 31),
      details: const [],
      accountSummaries: const [],
      customerSummaries: const [],
      supplierSummaries: const [],
      totalCustomerGrossRefundOutflow: 0,
      totalCustomerRefundReversals: 0,
      totalCustomerNetRefundOutflow: 0,
      totalSupplierGrossRefundInflow: 0,
      totalSupplierRefundReversals: 0,
      totalSupplierNetRefundInflow: 0,
      signedGrandCashEffect: 0,
    );
  }
  final account = FinancialAccount(
    id: 'bank',
    name: 'Bank account',
    type: FinancialAccountType.bank,
    isActive: false,
    createdByUserId: 'owner',
    createdAt: DateTime(2026),
  );
  return AdvancesAndRefundsReport(
    fromDate: DateTime(2026, 1),
    toDate: DateTime(2026, 1, 31),
    details: [
      AdvancesAndRefundsDetail(
        entryId: 'supplier-row',
        accountId: 'bank',
        accountName: 'Bank account',
        partyType: AdvancesAndRefundsPartyType.supplier,
        entityName: 'Canonical unresolved supplier',
        timestamp: DateTime(2026, 1, 20),
        sourceType: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
        isReversal: true,
        amountQirsh: 101,
        signedCashEffect: 101,
        sourceDocumentId: 'supplier-source',
        reversalOfEntryId: 'original-entry',
      ),
      AdvancesAndRefundsDetail(
        entryId: 'customer-row',
        accountId: 'bank',
        accountName: 'Bank account',
        partyType: AdvancesAndRefundsPartyType.customer,
        entityId: 'customer-1',
        entityName: 'Canonical customer',
        timestamp: DateTime(2026, 1, 5),
        sourceType: FinancialAccountEntrySource.customerAdvanceRefund,
        isReversal: false,
        amountQirsh: 33,
        signedCashEffect: -33,
        reference: 'customer-reference',
        sourceDocumentId: 'customer-source',
      ),
    ],
    accountSummaries: [
      AdvancesAndRefundsAccountSummary(
        account: account,
        customerGrossRefundOutflow: 33,
        customerRefundReversals: 7,
        customerNetRefundOutflow: 26,
        supplierGrossRefundInflow: 101,
        supplierRefundReversals: 7,
        supplierNetRefundInflow: 94,
        signedNetCashEffect: 68,
        detailCount: 2,
      ),
    ],
    customerSummaries: [
      const AdvancesAndRefundsEntitySummary(
        partyType: AdvancesAndRefundsPartyType.customer,
        entityId: 'customer-1',
        entityName: 'Canonical customer',
        grossAmount: 33,
        reversalAmount: 7,
        netAmount: 26,
        accountCount: 1,
        detailCount: 1,
      ),
    ],
    supplierSummaries: [
      const AdvancesAndRefundsEntitySummary(
        partyType: AdvancesAndRefundsPartyType.supplier,
        entityName: 'Canonical unresolved supplier',
        grossAmount: 101,
        reversalAmount: 7,
        netAmount: 94,
        accountCount: 1,
        detailCount: 1,
      ),
    ],
    totalCustomerGrossRefundOutflow: 33,
    totalCustomerRefundReversals: 7,
    totalCustomerNetRefundOutflow: 26,
    totalSupplierGrossRefundInflow: 101,
    totalSupplierRefundReversals: 7,
    totalSupplierNetRefundInflow: 94,
    signedGrandCashEffect: 68,
  );
}

final class _Reader implements FinancialAdvancesAndRefundsReportReader {
  _Reader(this.report);

  final AdvancesAndRefundsReport report;
  int calls = 0;

  @override
  Future<AdvancesAndRefundsReport> loadAdvancesAndRefundsReport() async {
    calls++;
    return report;
  }
}

final class _FailingReader implements FinancialAdvancesAndRefundsReportReader {
  @override
  Future<AdvancesAndRefundsReport> loadAdvancesAndRefundsReport() =>
      Future<AdvancesAndRefundsReport>.error(StateError('storage details'));
}

final class _InventoryReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() async => const [];
}
