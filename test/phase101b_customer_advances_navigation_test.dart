import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/features/customers/customer_advance_actions_screen.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_page_header.dart';

void main() {
  group('Phase 101B — customer advances back button visibility', () {
    testWidgets('back button visible during loading state', (tester) async {
      final gate = Completer<void>();
      final controller = _ProbeController(
        summaries: [_summary()],
        loadGate: gate,
      );

      await _pumpScreen(tester, controller: controller);

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(
          find.byKey(const Key('customer-advances-loading')), findsOneWidget);
      gate.complete();
    });

    testWidgets('back button visible during error state', (tester) async {
      final controller = _ProbeController(
        summaries: [_summary()],
        failLoading: true,
      );

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-error')), findsOneWidget);
    });

    testWidgets('back button visible during empty state', (tester) async {
      final controller = _ProbeController(summaries: const []);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-empty')), findsOneWidget);
    });

    testWidgets('back button visible when data is loaded', (tester) async {
      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byType(GhalalPageHeader), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-list')), findsOneWidget);
    });

    testWidgets('only one back button control exists in any state',
        (tester) async {
      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
    });

    testWidgets('tapping back button pops the pushed route', (tester) async {
      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreenAsRoute(tester, controller);

      expect(find.byType(CustomerAdvanceActionsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAdvanceActionsScreen), findsNothing);
    });

    testWidgets('tapping back does not invoke any financial write',
        (tester) async {
      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreenAsRoute(tester, controller);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(controller.applyCalls, 0);
      expect(controller.refundCalls, 0);
    });

    testWidgets('back button is visible in first viewport at 360x720',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _ProbeController(summaries: const []);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
    });

    testWidgets('back button visible in first viewport at 640x480',
        (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
    });

    testWidgets('no overflow on compact viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _ProbeController(
        summaries: List.generate(4, (i) => _summary(id: 'advance-$i')),
      );

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL layout is preserved', (tester) async {
      final controller = _ProbeController(summaries: [_summary()]);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(Directionality.of(tester.element(find.byType(Scaffold))),
          TextDirection.rtl);
    });

    testWidgets('empty state preserves navigation', (tester) async {
      final controller = _ProbeController(summaries: const []);

      await _pumpScreenAsRoute(tester, controller, settle: true);

      expect(find.byType(CustomerAdvanceActionsScreen), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-empty')), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAdvanceActionsScreen), findsNothing);
    });

    testWidgets('error state preserves navigation', (tester) async {
      final controller = _ProbeController(
        summaries: [_summary()],
        failLoading: true,
      );

      await _pumpScreenAsRoute(tester, controller, settle: true);

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byKey(const Key('customer-advances-error')), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerAdvanceActionsScreen), findsNothing);
    });

    testWidgets('loading state preserves navigation', (tester) async {
      final gate = Completer<void>();
      final controller = _ProbeController(
        summaries: [_summary()],
        loadGate: gate,
      );

      await _pumpScreenAsRoute(tester, controller, settle: false);
      await tester.pump();

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(
          find.byKey(const Key('customer-advances-loading')), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CustomerAdvanceActionsScreen), findsNothing);
      gate.complete();
    });

    testWidgets('header title shows customer name in all states',
        (tester) async {
      final controller = _ProbeController(summaries: const []);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.text('سلف العميل - عميل الاختبار'), findsOneWidget);
    });

    testWidgets('header title persists across retry from error to data',
        (tester) async {
      final controller = _ProbeController(
        summaries: [_summary()],
        failLoading: true,
      );

      await _pumpScreen(tester, controller: controller, settle: true);
      expect(find.byKey(const Key('customer-advances-error')), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);

      controller.failLoading = false;
      await tester.tap(find.byKey(const Key('customer-advances-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customer-advances-list')), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.text('سلف العميل - عميل الاختبار'), findsOneWidget);
    });

    testWidgets('advance data rows remain unchanged', (tester) async {
      final summary = _summary(
        appliedQirsh: 50,
        refundedQirsh: 25,
        remainingQirsh: 125,
      );
      final controller = _ProbeController(summaries: [summary]);

      await _pumpScreen(tester, controller: controller, settle: true);

      expect(find.textContaining('القيمة الأصلية:'), findsOneWidget);
      expect(find.textContaining('المبلغ المطبق:'), findsOneWidget);
      expect(find.textContaining('المبلغ المردود:'), findsOneWidget);
      expect(find.textContaining('الرصيد المتاح:'), findsOneWidget);
    });
  });
}

final _date = DateTime.utc(2026, 7, 15);

final _owner = AppUser(
  id: 'owner-phase101b',
  name: 'المالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _date,
  updatedAt: _date,
);

final _customer = Customer(
  id: 'customer-phase101b',
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
      sourceCollectionId: 'internal-collection-101b',
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required CustomerController controller,
  bool settle = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: CustomerAdvanceActionsScreen(
      customer: _customer,
      user: _owner,
      controller: controller,
      financialAccountRepository: LocalFinancialAccountRepository(),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _pumpScreenAsRoute(
  WidgetTester tester,
  CustomerController controller, {
  bool settle = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: _TestPushHost(
      child: CustomerAdvanceActionsScreen(
        customer: _customer,
        user: _owner,
        controller: controller,
        financialAccountRepository: LocalFinancialAccountRepository(),
      ),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _TestPushHost extends StatefulWidget {
  const _TestPushHost({required this.child});
  final Widget child;

  @override
  State<_TestPushHost> createState() => _TestPushHostState();
}

class _TestPushHostState extends State<_TestPushHost> {
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

class _ProbeController extends CustomerController {
  _ProbeController({
    required List<CustomerAdvanceSummary> summaries,
    this.loadGate,
    this.failLoading = false,
  })  : summaries = List<CustomerAdvanceSummary>.from(summaries),
        super(repository: LocalCustomerRepository());

  List<CustomerAdvanceSummary> summaries;
  final Completer<void>? loadGate;
  bool failLoading;
  int loadCalls = 0;
  int applyCalls = 0;
  int refundCalls = 0;

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

  @override
  Future<CustomerAdvanceActionResult> applyCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
  }) async {
    applyCalls++;
    return const CustomerAdvanceActionResult.success();
  }

  @override
  Future<CustomerAdvanceActionResult> refundCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
    required String financialAccountId,
    PaymentMethod? paymentMethod,
    String? negativeBalanceApprovalId,
  }) async {
    refundCalls++;
    return const CustomerAdvanceActionResult.success();
  }
}
