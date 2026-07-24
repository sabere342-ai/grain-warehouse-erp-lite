import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customer_advance_actions_screen.dart';
import 'package:grain_warehouse_erp_lite/features/suppliers/supplier_advance_actions_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';

void main() {
  group('Phase 92 supplier advance actions design-system migration', () {
    testWidgets('uses GhalalPageHeader instead of legacy AppBar',
        (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('shows the correct title with supplier name', (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      expect(find.text('سلف المورد - مورد الاختبار'), findsOneWidget);
    });

    testWidgets('has a back button with tooltip', (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      final backButton = find.byTooltip('رجوع');
      expect(backButton, findsOneWidget);
    });

    testWidgets('tapping back button pops the screen', (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreenAsRoute(tester, fixture);

      expect(find.byType(SupplierAdvanceActionsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(SupplierAdvanceActionsScreen), findsNothing);
    });

    testWidgets('main actions remain visible and functional', (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      expect(find.text('تطبيق السلفة'), findsOneWidget);
      expect(find.text('استرداد السلفة من المورد'), findsOneWidget);
      expect(find.byKey(const Key('supplier-advances-list')), findsOneWidget);
    });

    testWidgets('no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('scrolling reveals content below the fold', (tester) async {
      final fixture = await _SupplierFixture.create(withPayable: true);
      await _pumpSupplierScreen(tester, fixture);

      await tester.scrollUntilVisible(
        find.text('سجل المبالغ المستردة من المورد'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('سجل المبالغ المستردة من المورد'), findsOneWidget);
    });

    testWidgets('RTL layout is preserved', (tester) async {
      final fixture = await _SupplierFixture.create();
      await _pumpSupplierScreen(tester, fixture);

      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
    });

    testWidgets('loading and empty states still work', (tester) async {
      final fixture = await _SupplierFixture.create();
      await tester.pumpWidget(MaterialApp(
        home: SupplierAdvanceActionsScreen(
          supplier: fixture.supplier,
          user: _owner,
          controller: fixture.controller,
          financialAccountRepository: fixture.accounts,
        ),
      ));
      expect(
          find.byKey(const Key('supplier-advances-loading')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('supplier-advances-list')), findsOneWidget);
    });
  });

  group('Phase 92 customer advance actions design-system migration', () {
    testWidgets('uses GhalalPageHeader instead of legacy AppBar',
        (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('shows the correct title with customer name', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(find.text('سلف العميل - عميل الاختبار'), findsOneWidget);
    });

    testWidgets('has a back button with tooltip', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
    });

    testWidgets('tapping back button pops the screen', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreenAsRoute(tester, controller);

      expect(find.byType(CustomerAdvanceActionsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAdvanceActionsScreen), findsNothing);
    });

    testWidgets('main actions remain visible', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(find.text('تطبيق السلفة'), findsOneWidget);
      expect(find.text('رد السلفة'), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-list')), findsOneWidget);
    });

    testWidgets('no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _ProbeCustomerController(
        summaries: List.generate(4, (i) => _summary(id: 'advance-$i')),
      );
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('scrolling reveals content below the fold', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      await tester.scrollUntilVisible(
        find.text('سجل الاستردادات'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('سجل الاستردادات'), findsOneWidget);
    });

    testWidgets('RTL layout is preserved', (tester) async {
      final controller = _ProbeCustomerController(summaries: [_summary()]);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);

      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
    });

    testWidgets('loading, error and empty states still work', (tester) async {
      final gate = Completer<void>();
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        loadGate: gate,
      );
      await _pumpCustomerScreen(tester, controller: controller);
      expect(
          find.byKey(const Key('customer-advances-loading')), findsOneWidget);
      gate.complete();
    });

    testWidgets('empty state works', (tester) async {
      final controller = _ProbeCustomerController(summaries: const []);
      await _pumpCustomerScreen(tester, controller: controller, settle: true);
      expect(find.byKey(const Key('customer-advances-empty')), findsOneWidget);
    });

    testWidgets('error state works', (tester) async {
      final controller = _ProbeCustomerController(
        summaries: [_summary()],
        failLoading: true,
      );
      await _pumpCustomerScreen(tester, controller: controller, settle: true);
      expect(find.byKey(const Key('customer-advances-error')), findsOneWidget);
    });
  });
}

final _date = DateTime.utc(2026, 7, 15);

final _owner = AppUser(
  id: 'owner-phase92',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _date,
  updatedAt: _date,
);

final _customer = Customer(
  id: 'customer-phase92',
  name: 'عميل الاختبار',
  isActive: true,
  createdAt: _date,
  updatedAt: _date,
);

CustomerAdvanceSummary _summary({
  String id = 'advance-visible',
  String accountId = 'account-1',
  int appliedQirsh = 0,
  int refundedQirsh = 0,
  int remainingQirsh = 200,
  bool reversed = false,
}) {
  return CustomerAdvanceSummary(
    advance: CustomerAdvance(
      id: id,
      customerId: _customer.id,
      sourceCollectionId: 'internal-collection-phase92',
      financialAccountId: accountId,
      amountQirsh: 200,
      createdAt: _date,
      createdByUserId: _owner.id,
      ownerApprovalId: 'internal-owner-approval',
      operationRequestId: 'internal-create-request',
      paymentMethod: PaymentMethod.cash,
      reversedAt: reversed ? _date : null,
      reversedByUserId: reversed ? _owner.id : null,
    ),
    appliedQirsh: appliedQirsh,
    refundedQirsh: refundedQirsh,
    remainingQirsh: remainingQirsh,
  );
}

Future<void> _pumpSupplierScreen(
  WidgetTester tester,
  _SupplierFixture fixture,
) async {
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

Future<void> _pumpCustomerScreen(
  WidgetTester tester, {
  required CustomerController controller,
  FinancialAccountRepository? accounts,
  CustomerAdvanceApprovalPrompt? approvalPrompt,
  bool settle = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: CustomerAdvanceActionsScreen(
      customer: _customer,
      user: _owner,
      controller: controller,
      financialAccountRepository: accounts ?? LocalFinancialAccountRepository(),
      approvalPrompt: approvalPrompt,
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _SupplierFixture {
  const _SupplierFixture({
    required this.supplier,
    required this.account,
    required this.accounts,
    required this.ledger,
    required this.advance,
    required this.controller,
  });

  final Supplier supplier;
  final FinancialAccount account;
  final LocalFinancialAccountRepository accounts;
  final LocalSupplierAccountRepository ledger;
  final SupplierAdvance advance;
  final _ProbeSupplierController controller;

  static Future<_SupplierFixture> create({bool withPayable = false}) async {
    final audit = LocalAuditLogRepository();
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit);
    final account = await accounts.createAccount(const FinancialAccountDraft(
      name: 'الخزينة',
      type: FinancialAccountType.treasury,
      createdByUserId: 'owner-phase92',
    ));
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers
        .createSupplier(const SupplierDraft(name: 'مورد الاختبار'));
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    final advance = SupplierAdvance(
      id: 'supplier-advance-phase92',
      supplierId: supplier.id,
      sourcePaymentId: 'supplier-payment-phase92',
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
    return _SupplierFixture(
      supplier: supplier,
      account: account,
      accounts: accounts,
      ledger: ledger,
      advance: advance,
      controller: controller,
    );
  }
}

class _ProbeSupplierController extends SupplierController {
  _ProbeSupplierController({
    required super.repository,
    required super.accountRepository,
    required this.summary,
  });

  final SupplierAdvanceSummary summary;

  @override
  Future<List<SupplierAdvanceSummary>> advancesForSupplier(
          String supplierId) async =>
      [summary];
}

class _ProbeCustomerController extends CustomerController {
  _ProbeCustomerController({
    required List<CustomerAdvanceSummary> summaries,
    this.loadGate,
    this.failLoading = false,
  })  : summaries = List<CustomerAdvanceSummary>.from(summaries),
        super(repository: LocalCustomerRepository());

  List<CustomerAdvanceSummary> summaries;
  final Completer<void>? loadGate;
  bool failLoading;
  int loadCalls = 0;

  @override
  int balanceForCustomer(String customerId) => 10000;

  @override
  Future<List<CustomerAdvanceSummary>> advancesForCustomer(
      String customerId) async {
    loadCalls++;
    if (loadGate != null) await loadGate!.future;
    if (failLoading) throw StateError('technical load failure');
    return List<CustomerAdvanceSummary>.unmodifiable(summaries);
  }
}

Future<void> _pumpSupplierScreenAsRoute(
  WidgetTester tester,
  _SupplierFixture fixture,
) async {
  await tester.pumpWidget(MaterialApp(
    home: _TestPushScreen(
      child: SupplierAdvanceActionsScreen(
        supplier: fixture.supplier,
        user: _owner,
        controller: fixture.controller,
        financialAccountRepository: fixture.accounts,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpCustomerScreenAsRoute(
  WidgetTester tester,
  CustomerController controller,
) async {
  await tester.pumpWidget(MaterialApp(
    home: _TestPushScreen(
      child: CustomerAdvanceActionsScreen(
        customer: _customer,
        user: _owner,
        controller: controller,
        financialAccountRepository: LocalFinancialAccountRepository(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _TestPushScreen extends StatefulWidget {
  const _TestPushScreen({required this.child});
  final Widget child;

  @override
  State<_TestPushScreen> createState() => _TestPushScreenState();
}

class _TestPushScreenState extends State<_TestPushScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => widget.child),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
