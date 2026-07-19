import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_controller.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_shell.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/inventory_screen.dart';
import 'package:grain_warehouse_erp_lite/features/inventory/stock_adjustment_report_screen.dart';

void main() {
  group('StockAdjustmentReportScreen', () {
    testWidgets('renders report page', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixture();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('تقرير تسويات المخزون'), findsOneWidget);
      expect(
        find.textContaining('ولا يقوم بتعديل الكميات'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no manual movements exist',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('لا توجد تسويات مخزون مسجلة حتى الآن.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'visible back control safely returns to Inventory without a movement',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();
      final movementCountBefore =
          (await fixture.inventory.listAllMovements()).length;

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.fact_check_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(StockAdjustmentReportScreen), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byKey(const ValueKey('stock-adjustment-report-back-button')),
          findsOneWidget);
      expect(Icons.arrow_forward_rounded.matchTextDirection, isTrue);

      await tester.tap(find.text('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(StockAdjustmentReportScreen), findsNothing);
      expect(find.byType(InventoryScreen), findsOneWidget);
      expect((await fixture.inventory.listAllMovements()).length,
          movementCountBefore);
    });

    testWidgets('header uses semantic colors in the dark preset',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixture();
      final theme = AppTheme.fromPreset(AppThemePreset.highContrast);

      await tester.pumpWidget(
        _reportHarness(
          auth: auth,
          controller: fixture.controller,
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('تقرير تسويات المخزون'));
      final subtitle = tester.widget<Text>(find.textContaining(
        'ولا يقوم بتعديل الكميات',
      ));
      expect(title.style?.color, theme.colorScheme.onSurface);
      expect(subtitle.style?.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('manual increase appears in report', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-زيادة مراجعة')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('زيادة يدوية'), findsWidgets);
      expect(find.text('زيادة مراجعة'), findsOneWidget);
      expect(find.text('300 كجم'), findsWidgets);
    });

    testWidgets('manual decrease appears in report', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-نقص مراجعة')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('نقص يدوي'), findsWidgets);
      expect(find.text('نقص مراجعة'), findsOneWidget);
      expect(find.text('100 كجم'), findsWidgets);
    });

    testWidgets('non-manual movements are excluded', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();
      await fixture.inventory.createMovement(
        StockMovementDraft(
          productId: fixture.product.id,
          movementType: StockMovementType.purchaseIntake,
          quantityKg: 250,
          createdByUserId: _owner.id,
          note: 'استلام شراء للاختبار',
        ),
      );
      await fixture.controller.load(_owner);

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('استلام شراء'), findsNothing);
      expect(find.text('استلام شراء للاختبار'), findsNothing);
    });

    testWidgets('totals calculate increases, decreases, and net correctly',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إجمالي الزيادة اليدوية'), findsOneWidget);
      expect(find.text('إجمالي النقص اليدوي'), findsOneWidget);
      expect(find.text('صافي التسوية'), findsOneWidget);
      expect(find.text('350 كجم'), findsWidgets);
      expect(find.text('100 كجم'), findsWidgets);
      expect(find.text('+250 كجم'), findsOneWidget);
    });

    testWidgets('product search filters rows', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithTwoProducts();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ذرة');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-نقص ذرة')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('ذرة'), findsWidgets);
      expect(find.text('قمح'), findsNothing);
      expect(find.text('75 كجم'), findsWidgets);
    });

    testWidgets('movement type filter works', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('stock-adjustment-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نقص يدوي').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-نقص مراجعة')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('نقص مراجعة'), findsOneWidget);
      expect(find.text('زيادة مراجعة'), findsNothing);
      expect(find.text('-100 كجم'), findsOneWidget);
    });

    testWidgets('stock-taking reason appears and stock-take filter works',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-تسوية جرد المخزون')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('تسوية جرد المخزون'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stock-adjustment-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسويات الجرد فقط').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock-adjustment-card-تسوية جرد المخزون')),
        300,
        scrollable: _reportScrollable,
      );

      expect(find.text('تسوية جرد المخزون'), findsOneWidget);
      expect(find.text('زيادة مراجعة'), findsNothing);
      expect(find.text('نقص مراجعة'), findsNothing);
    });

    testWidgets('report is read-only and does not mutate stock',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();
      final before = fixture.controller.balanceForProduct(fixture.product.id);

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحديث'));
      await tester.pumpAndSettle();

      expect(fixture.controller.balanceForProduct(fixture.product.id), before);
    });

    testWidgets('customer and supplier balances are not mutated',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();
      final customers = LocalCustomerRepository();
      final customer = await customers.createCustomer(
        const CustomerDraft(name: 'عميل اختبار'),
      );
      final customerAccounts = LocalCustomerAccountRepository(
        customerRepository: customers,
      );
      await customerAccounts.createOpeningBalanceEntry(
        customerId: customer.id,
        amountQirsh: 50000,
        createdByUserId: _owner.id,
      );
      final suppliers = LocalSupplierRepository();
      final supplier = await suppliers.createSupplier(
        const SupplierDraft(name: 'مورد اختبار'),
      );
      final supplierAccounts = LocalSupplierAccountRepository(
        supplierRepository: suppliers,
      );
      await supplierAccounts.createOpeningBalanceEntry(
        supplierId: supplier.id,
        amountQirsh: 80000,
        createdByUserId: _owner.id,
      );

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(await customerAccounts.balanceForCustomer(customer.id), 50000);
      expect(await supplierAccounts.balanceForSupplier(supplier.id), 80000);
    });

    testWidgets('permission gating blocks employee', (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('هذا التقرير متاح للمالك فقط.'), findsOneWidget);
      expect(find.text('زيادة مراجعة'), findsNothing);
    });

    testWidgets('dashboard shell shows report entry for owner', (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_dashboardHarness(auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('تقرير التسويات'), findsOneWidget);
    });

    testWidgets('dashboard shell hides report entry for employee',
        (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_dashboardHarness(auth: auth));
      await tester.pumpAndSettle();

      expect(find.text('تقرير التسويات'), findsNothing);
    });

    testWidgets('report states before and after stock is unavailable',
        (tester) async {
      final auth = await _signedInController(
        phone: '01000000000',
        password: 'owner123',
      );
      final fixture = await _fixtureWithAdjustments();

      await tester.pumpWidget(
        _reportHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('stock-adjustment-before-after-تسوية جرد المخزون'),
        ),
        300,
        scrollable: _reportScrollable,
      );

      expect(
        find.textContaining('أرصدة قبل/بعد الحركة غير متوفرة'),
        findsOneWidget,
      );
      expect(
        find.textContaining('الرصيد قبل/بعد الحركة: غير متوفر'),
        findsWidgets,
      );
    });
  });
}

final _reportScrollable = find
    .descendant(
      of: find.byKey(const Key('stock-adjustment-report-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<_ReportFixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(_productDraft('قمح'));
  final inventory = LocalInventoryRepository(productRepository: products);
  final controller = InventoryController(
    inventoryRepository: inventory,
    productRepository: products,
  );
  await controller.load(_owner);

  return _ReportFixture(
    products: products,
    inventory: inventory,
    controller: controller,
    product: product,
  );
}

Future<_ReportFixture> _fixtureWithAdjustments() async {
  final fixture = await _fixture();
  await fixture.controller.createOpeningBalance(
    user: _owner,
    productId: fixture.product.id,
    quantityKg: 1000,
  );
  await fixture.controller.createManualIncrease(
    user: _owner,
    productId: fixture.product.id,
    quantityKg: 300,
    note: 'زيادة مراجعة',
  );
  await fixture.controller.createManualDecrease(
    user: _owner,
    productId: fixture.product.id,
    quantityKg: 100,
    note: 'نقص مراجعة',
  );
  await fixture.controller.createManualIncrease(
    user: _owner,
    productId: fixture.product.id,
    quantityKg: 50,
    note: 'تسوية جرد المخزون',
  );
  return fixture;
}

Future<_ReportFixture> _fixtureWithTwoProducts() async {
  final fixture = await _fixtureWithAdjustments();
  final corn = await fixture.products.createProduct(_productDraft('ذرة'));
  await fixture.controller.load(_owner);
  await fixture.controller.createOpeningBalance(
    user: _owner,
    productId: corn.id,
    quantityKg: 500,
  );
  await fixture.controller.createManualDecrease(
    user: _owner,
    productId: corn.id,
    quantityKg: 75,
    note: 'نقص ذرة',
  );
  return fixture;
}

ProductDraft _productDraft(String name) {
  return ProductDraft(
    name: name,
    unit: GrainUnit.kilogram,
  );
}

Widget _reportHarness({
  required AuthController auth,
  required InventoryController controller,
  ThemeData? theme,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: StockAdjustmentReportScreen(controller: controller),
      ),
    ),
  );
}

Widget _inventoryHarness({
  required AuthController auth,
  required InventoryController controller,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('المخزون')),
        body: InventoryScreen(controller: controller),
      ),
    ),
  );
}

Widget _dashboardHarness({
  required AuthController auth,
}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const DashboardShell(),
    ),
  );
}

class _ReportFixture {
  const _ReportFixture({
    required this.products,
    required this.inventory,
    required this.controller,
    required this.product,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final InventoryController controller;
  final Product product;
}

final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

Future<AuthController> _signedInController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}
