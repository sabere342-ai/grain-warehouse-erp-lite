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
import 'package:grain_warehouse_erp_lite/features/inventory/stock_take_screen.dart';

void main() {
  group('StockTakeScreen UI', () {
    testWidgets('renders product list with system stock', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('جرد المخزون'), findsOneWidget);
      expect(find.text(fixture.product.name), findsOneWidget);
      expect(find.text('الرصيد النظامي: 1000 كجم'), findsOneWidget);
    });

    testWidgets('shows permission denied for employee', (tester) async {
      final auth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final fixture = await _fixture();

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('هذه الصفحة متاحة للمالك فقط.'), findsOneWidget);
    });

    testWidgets('shows empty state when no products', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final products = LocalProductRepository();
      final inventory = LocalInventoryRepository(productRepository: products);
      final controller = InventoryController(
        inventoryRepository: inventory,
        productRepository: products,
      );
      await controller.load(_owner);

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('لا توجد أصناف نشطة'),
        findsOneWidget,
      );
    });

    testWidgets('displays variance in real time', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      final actualField = find.byType(TextField);
      expect(actualField, findsOneWidget);

      await tester.enterText(actualField, '1200');
      await tester.pump();

      expect(find.text('الفرق: +200 كجم'), findsOneWidget);
    });

    testWidgets('shows negative variance correctly', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '800');
      await tester.pump();

      expect(find.text('الفرق: -200 كجم'), findsOneWidget);
    });

    testWidgets('shows zero variance when actual equals system',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();

      expect(find.text('الفرق: 0 كجم'), findsOneWidget);
    });

    testWidgets('apply button is present', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('تطبيق التسوية'), findsOneWidget);
    });

    testWidgets('back control is visible in the empty state from Inventory',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final products = LocalProductRepository();
      final controller = InventoryController(
        inventoryRepository: LocalInventoryRepository(
          productRepository: products,
        ),
        productRepository: products,
      );
      await controller.load(_owner);

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.balance_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(StockTakeScreen), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('stock-take-back-button')), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          'inventory route paints the $brightness stock-take theme surface',
          (tester) async {
        final auth = await _signedInController(
          phone: '01000000000',
          password: 'owner123',
        );
        final products = LocalProductRepository();
        final controller = InventoryController(
          inventoryRepository: LocalInventoryRepository(
            productRepository: products,
          ),
          productRepository: products,
        );
        await controller.load(_owner);
        final theme =
            brightness == Brightness.light ? AppTheme.light : AppTheme.dark;

        await tester.pumpWidget(
          _inventoryHarness(
            auth: auth,
            controller: controller,
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.balance_rounded));
        await tester.pumpAndSettle();

        final routeScaffold = tester.widget<Scaffold>(
          find.byKey(const Key('stock-take-route-scaffold')),
        );
        expect(routeScaffold.backgroundColor, theme.scaffoldBackgroundColor);
        if (brightness == Brightness.light) {
          expect(routeScaffold.backgroundColor, isNot(Colors.black));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'back control pops the inventory route once without creating a write',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );
      final movementCountBefore =
          (await fixture.inventory.listAllMovements()).length;

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.balance_rounded));
      await tester.pumpAndSettle();

      expect(find.byTooltip('رجوع'), findsOneWidget);
      expect(find.byTooltip('رجوع'), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.byType(StockTakeScreen), findsNothing);
      expect(find.byType(InventoryScreen), findsOneWidget);
      expect((await fixture.inventory.listAllMovements()).length,
          movementCountBefore);
    });

    testWidgets('back control remains visible after stocktake validation',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.balance_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pump();

      expect(find.byTooltip('رجوع'), findsOneWidget);
    });

    testWidgets('header uses semantic colors in the dark preset',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      final theme = AppTheme.fromPreset(AppThemePreset.highContrast);

      await tester.pumpWidget(
        _stockTakeHarness(
          auth: auth,
          controller: fixture.controller,
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('جرد المخزون'));
      final subtitle = tester.widget<Text>(find.text(
        'أدخل الكمية الفعلية التي تم عدّها، وسيقوم النظام بحساب الفرق وتسجيل حركة تسوية فقط عند وجود فرق.',
      ));
      expect(title.style?.color, theme.colorScheme.onSurface);
      expect(subtitle.style?.color, theme.colorScheme.onSurfaceVariant);
    });
  });

  group('StockTakeScreen logic', () {
    testWidgets('rejects invalid actual input', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pump();

      expect(
        find.textContaining('الكمية غير صحيحة'),
        findsOneWidget,
      );
    });

    testWidgets('rejects negative actual input', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '-5');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pump();

      expect(
        find.textContaining('الكمية غير صحيحة'),
        findsOneWidget,
      );
    });

    testWidgets('shows message when no variance to adjust', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pump();

      expect(
        find.text(
            'لا يوجد فرق للتسوية. أدخل العد الفعلي للأصناف المطلوب جردها.'),
        findsOneWidget,
      );
      final movements = await fixture.inventory.listAllMovements();
      expect(movements, hasLength(1));
    });

    testWidgets('creates manual increase for positive variance',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1200');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('تأكيد تسوية الجرد'), findsOneWidget);
      expect(find.textContaining('الفعلي 1200 كجم'), findsOneWidget);
      expect(find.text('تأكيد التسوية'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // No movement created
      expect(fixture.controller.balanceForProduct(fixture.product.id), 1000);
    });

    testWidgets('applies stock take and creates movements on confirm',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1200');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد التسوية'), findsOneWidget);
      await tester.tap(find.text('تأكيد التسوية'));
      await tester.pumpAndSettle();

      expect(fixture.controller.balanceForProduct(fixture.product.id), 1200);
      final movements = await fixture.inventory.listAllMovements();
      expect(movements, hasLength(2));
      expect(movements.last.movementType, StockMovementType.manualIncrease);
      expect(movements.last.quantityKg, 200);
      expect(movements.last.note, 'تسوية جرد المخزون');
      expect(find.text('تم تسوية 1 صنف بنجاح.'), findsOneWidget);
    });

    testWidgets('creates manual decrease for negative variance',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '700');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد التسوية'), findsOneWidget);
      await tester.tap(find.text('تأكيد التسوية'));
      await tester.pumpAndSettle();

      expect(fixture.controller.balanceForProduct(fixture.product.id), 700);
      final movements = await fixture.inventory.listAllMovements();
      expect(movements, hasLength(2));
      expect(movements.last.movementType, StockMovementType.manualDecrease);
      expect(movements.last.quantityKg, 300);
      expect(movements.last.note, 'تسوية جرد المخزون');
    });

    testWidgets('rejects empty actual input before applying', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pump();

      expect(
        find.text('أدخل الكمية الفعلية لكل صنف قبل تطبيق تسوية الجرد.'),
        findsOneWidget,
      );
    });

    testWidgets('does not mutate customer or supplier balances',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );
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
        _stockTakeHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1200');
      await tester.tap(find.text('تطبيق التسوية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد التسوية'));
      await tester.pumpAndSettle();

      expect(await customerAccounts.balanceForCustomer(customer.id), 50000);
      expect(await supplierAccounts.balanceForSupplier(supplier.id), 80000);
    });

    testWidgets('dashboard shell shows stock take tab for owner',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _dashboardHarness(auth: auth),
      );
      await tester.pumpAndSettle();

      expect(find.text('جرد المخزون'), findsOneWidget);
    });

    testWidgets('inventory screen has stock take button for owner',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.controller.createOpeningBalance(
        user: _owner,
        productId: fixture.product.id,
        quantityKg: 1000,
      );

      await tester.pumpWidget(
        _inventoryHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('جرد المخزون'), findsOneWidget);
    });

    testWidgets(
        'dashboard shell tab shows shell-back-button and hides stock-take-back-button',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_dashboardHarness(auth: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('جرد المخزون'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-back-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('stock-take-back-button')),
        findsNothing,
      );
    });

    testWidgets(
        'dashboard shell tab shell-back-button returns to home without stock write',
        (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_dashboardHarness(auth: auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('جرد المخزون'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-back-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('shell-back-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-back-button')), findsNothing);
    });
  });
}

ProductDraft _productDraft(String name) {
  return ProductDraft(
    name: name,
    unit: GrainUnit.kilogram,
  );
}

Future<_StockTakeFixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(_productDraft('قمح'));
  final inventory = LocalInventoryRepository(productRepository: products);
  final controller = InventoryController(
    inventoryRepository: inventory,
    productRepository: products,
  );
  await controller.load(_owner);

  return _StockTakeFixture(
    products: products,
    inventory: inventory,
    controller: controller,
    product: product,
  );
}

Widget _stockTakeHarness({
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
        body: StockTakeScreen(controller: controller),
      ),
    ),
  );
}

Widget _inventoryHarness({
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

class _StockTakeFixture {
  const _StockTakeFixture({
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
