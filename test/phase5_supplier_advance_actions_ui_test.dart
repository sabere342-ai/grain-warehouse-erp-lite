import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/supplier_advance_actions_screen.dart';

void main() {
  group('Phase 5 supplier advance UI', () {
    testWidgets('shows the supplier values, RTL layout and available actions',
        (tester) async {
      final fixture = await _Fixture.create();
      await _pump(tester, fixture);

      expect(find.byKey(const Key('supplier-advances-list')), findsOneWidget);
      expect(find.text('سلف المورد - مورد الاختبار'), findsOneWidget);
      expect(find.text('قيمة السلفة'), findsOneWidget);
      expect(find.text('المبلغ المطبق'), findsOneWidget);
      expect(find.text('المبلغ المسترد'), findsOneWidget);
      expect(find.text('الرصيد المتاح'), findsOneWidget);
      expect(find.text('متاحة'), findsOneWidget);
      expect(find.text('تطبيق السلفة'), findsOneWidget);
      expect(find.text('استرداد السلفة من المورد'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
    });

    testWidgets('application validates input and applies only once',
        (tester) async {
      final fixture = await _Fixture.create(withPayable: true);
      await _pump(tester, fixture);
      await tester.tap(find.text('تطبيق السلفة'));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('supplier-advance-application-submit')));
      await tester.pump();
      expect(find.text('أدخل المبلغ أولًا.'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('supplier-advance-application-amount')), '1');
      await tester
          .tap(find.byKey(const Key('supplier-advance-application-submit')));
      await tester.pumpAndSettle();

      expect(fixture.controller.applyCalls, 1);
      expect(find.text('تم تطبيق السلفة بنجاح'), findsOneWidget);
    });

    testWidgets('refund requires an account and reports the inbound success',
        (tester) async {
      final fixture = await _Fixture.create();
      await _pump(tester, fixture);
      await tester.tap(find.text('استرداد السلفة من المورد'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('supplier-advance-refund-amount')), '1');
      await tester.tap(find.byKey(const Key('supplier-advance-refund-submit')));
      await tester.pump();
      expect(find.text('اختر الحساب المالي أولًا.'), findsOneWidget);

      await tester
          .tap(find.byKey(const Key('supplier-advance-refund-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('الخزينة').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('سيضيف المورد'), findsOneWidget);
      await tester.tap(find.byKey(const Key('supplier-advance-refund-submit')));
      for (var index = 0; index < 20; index++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (fixture.controller.refundCalls > 0) break;
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(fixture.controller.refundCalls, 1);
      expect(
          find.text('تم استرداد مبلغ السلفة من المورد بنجاح'), findsOneWidget);
    });
  });

  test('supplier refund is one replay-safe inflow with no approval contract',
      () async {
    final fixture = await _Fixture.create();
    const requestId = 'phase5-refund-contract';
    final draft = SupplierAdvanceRefundDraft(
      advanceId: fixture.advance.id,
      amountQirsh: 100,
      date: _date,
      createdByUserId: _owner.id,
      operationRequestId: requestId,
      financialAccountId: fixture.account.id,
    );

    final first = await fixture.ledger.refundAdvance(draft);
    final replay = await fixture.ledger.refundAdvance(draft);
    final statement =
        await fixture.accounts.statementForAccount(fixture.account.id);
    final entries = statement.lines
        .map((line) => line.entry)
        .where((entry) =>
            entry.sourceType ==
            FinancialAccountEntrySource.supplierAdvanceRefund)
        .toList();

    expect(replay.id, first.id);
    expect(entries, hasLength(1));
    expect(entries.single.direction, FinancialAccountEntryDirection.inflow);
    expect(entries.single.amountQirsh, 100);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id),
        100);
    expect(await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 100);
    expect((await fixture.ledger.listAdvanceRefunds()), hasLength(1));
  });
}

Future<void> _pump(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(MaterialApp(
    home: SupplierAdvanceActionsScreen(
      supplier: fixture.supplier,
      user: _owner,
      controller: fixture.controller,
      financialAccountRepository: fixture.accounts,
    ),
  ));
  await tester.pumpAndSettle();
}

final _date = DateTime.utc(2026, 7, 15);
final _owner = AppUser(
  id: 'owner-phase5',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _date,
  updatedAt: _date,
);

class _Fixture {
  const _Fixture(
      {required this.supplier,
      required this.account,
      required this.accounts,
      required this.ledger,
      required this.advance,
      required this.controller});
  final Supplier supplier;
  final FinancialAccount account;
  final LocalFinancialAccountRepository accounts;
  final LocalSupplierAccountRepository ledger;
  final SupplierAdvance advance;
  final _ProbeSupplierController controller;

  static Future<_Fixture> create({bool withPayable = false}) async {
    final audit = LocalAuditLogRepository();
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit);
    final account = await accounts.createAccount(const FinancialAccountDraft(
        name: 'الخزينة',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner-phase5'));
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers
        .createSupplier(const SupplierDraft(name: 'مورد الاختبار'));
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    final advance = SupplierAdvance(
      id: 'supplier-advance-phase5',
      supplierId: supplier.id,
      sourcePaymentId: 'supplier-payment-phase5',
      financialAccountId: account.id,
      amountQirsh: 200,
      createdAt: _date,
      createdByUserId: _owner.id,
      ownerApprovalId: 'creation-approval',
      operationRequestId: 'advance-creation-request',
      paymentMethod: PaymentMethod.cash,
    );
    await ledger.restoreSupplierAccountsIntoEmpty(
        entries: const [], payments: const [], advances: [advance]);
    if (withPayable) {
      await ledger.createOpeningBalanceEntry(
          supplierId: supplier.id,
          amountQirsh: 1000,
          createdByUserId: _owner.id);
    }
    final controller = _ProbeSupplierController(
      repository: suppliers,
      accountRepository: ledger,
      summary: SupplierAdvanceSummary(
        advance: advance,
        appliedQirsh: 0,
        refundedQirsh: 0,
        remainingQirsh: 200,
      ),
    );
    return _Fixture(
        supplier: supplier,
        account: account,
        accounts: accounts,
        ledger: ledger,
        advance: advance,
        controller: controller);
  }
}

class _ProbeSupplierController extends SupplierController {
  _ProbeSupplierController({
    required super.repository,
    required super.accountRepository,
    required this.summary,
  });

  final SupplierAdvanceSummary summary;
  int applyCalls = 0;
  int refundCalls = 0;

  @override
  Future<List<SupplierAdvanceSummary>> advancesForSupplier(
          String supplierId) async =>
      [summary];

  @override
  Future<SupplierAdvanceActionResult> applySupplierAdvance({
    required AppUser user,
    required SupplierAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
  }) async {
    applyCalls++;
    return const SupplierAdvanceActionResult.success();
  }

  @override
  Future<SupplierAdvanceActionResult> refundSupplierAdvance({
    required AppUser user,
    required SupplierAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
    required String financialAccountId,
    PaymentMethod? paymentMethod,
  }) async {
    refundCalls++;
    return const SupplierAdvanceActionResult.success();
  }
}
