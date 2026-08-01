import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Sales foundation', () {
    test('valid sale creates sale record', () async {
      final fixture = await _fixture();

      final sale = await fixture.sales.createSale(_saleDraft(fixture));

      expect(sale.id.trim(), isNotEmpty);
      expect(sale.hasValidId, isTrue);
      expect(sale.productId, fixture.product.id);
      expect(sale.quantityKg, 250);
      expect(sale.salePriceQirshPerKg, 700);
      expect(sale.totalQirsh, 175000);
      expect(await fixture.sales.listSales(), hasLength(1));
    });

    test('valid sale creates outgoing stock movement', () async {
      final fixture = await _fixture();

      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      final movements = await fixture.inventory.listAllMovements();
      final movement = movements.last;

      expect(movement.movementType, StockMovementType.sale);
      expect(movement.quantityKg, 250);
      expect(movement.signedQuantityKg, -250);
      expect(sale.stockMovementId, movement.id);
    });

    test('stock decreases correctly through inventory ledger', () async {
      final fixture = await _fixture();

      await fixture.sales.createSale(_saleDraft(fixture, quantityKg: 300));

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 700);
    });

    test('cancelling sale reverses stock decrease and preserves original',
        () async {
      final fixture = await _fixture();

      final sale = await fixture.sales.createSale(_saleDraft(fixture));
      final cancelled = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'خطأ في الإدخال',
      );
      final movements = await fixture.inventory.listAllMovements();

      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.cancellation!.cancelledByUserId, _owner.id);
      expect(cancelled.cancellation!.originalDocumentId, sale.id);
      expect(cancelled.cancellation!.reversalMovementIds, hasLength(1));
      expect(movements, hasLength(3));
      expect(movements[1].id, sale.stockMovementId);
      expect(movements[1].movementType, StockMovementType.sale);
      expect(movements.last.movementType, StockMovementType.saleCancellation);
      expect(movements.last.reversedMovementId, sale.stockMovementId);
      expect(movements.last.originalDocumentId, sale.id);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 1000);
    });

    test('double sale cancellation is idempotent', () async {
      final fixture = await _fixture();
      final sale = await fixture.sales.createSale(_saleDraft(fixture));

      final first = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'خطأ في الإدخال',
      );
      final second = await fixture.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: 'محاولة ثانية',
      );

      expect(second.cancellation!.reversalMovementIds,
          first.cancellation!.reversalMovementIds);
      expect(await fixture.inventory.listAllMovements(), hasLength(3));
    });

    test('controller allows owner and rejects employee sale cancellation',
        () async {
      final ownerFixture = await _fixture();
      final employeeFixture = await _fixture();
      final ownerSale = await ownerFixture.sales.createSale(
        _saleDraft(ownerFixture),
      );
      final employeeSale = await employeeFixture.sales.createSale(
        _saleDraft(employeeFixture),
      );

      expect(
        await ownerFixture.controller.cancelSale(
          user: _owner,
          saleId: ownerSale.id,
          cancellationReason: 'خطأ في الإدخال',
        ),
        isTrue,
      );
      expect(
        await employeeFixture.controller.cancelSale(
          user: _employee,
          saleId: employeeSale.id,
          cancellationReason: 'خطأ في الإدخال',
        ),
        isFalse,
      );
      expect(
          await ownerFixture.inventory.currentStockKg(ownerFixture.product.id),
          1000);
      expect(await employeeFixture.inventory.listAllMovements(), hasLength(2));
    });

    test('sale rejects zero and negative quantity', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, quantityKg: 0)),
        throwsArgumentError,
      );
      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, quantityKg: -1)),
        throwsArgumentError,
      );
    });

    test('sale rejects zero and negative price', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, price: 0)),
        throwsArgumentError,
      );
      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, price: -1)),
        throwsArgumentError,
      );
    });

    test('sale rejects insufficient stock without partial record', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, quantityKg: 1001)),
        throwsStateError,
      );
      expect(await fixture.sales.listSales(), isEmpty);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 1000);
    });

    test('sale rejects missing and inactive product', () async {
      final fixture = await _fixture();

      expect(
        () => fixture.sales.createSale(
          _saleDraft(fixture, productId: 'missing-product'),
        ),
        throwsStateError,
      );

      await fixture.products.setProductActive(
        productId: fixture.product.id,
        isActive: false,
      );
      expect(
        () => fixture.sales.createSale(_saleDraft(fixture)),
        throwsStateError,
      );
    });

    test('sale rejects unsafe numeric total', () async {
      final products = LocalProductRepository();
      final product = await products.createProduct(_productDraft());
      final sales = LocalSaleRepository(
        productRepository: products,
        inventoryRepository: _LargeStockInventoryRepository(product.id),
      );

      final testCustomer = await LocalCustomerRepository().createCustomer(
        const CustomerDraft(name: 'test', isActive: true),
      );
      expect(
        () => sales.createSale(
          SaleDraft(
            productId: product.id,
            quantityKg: 9223372036854775807,
            salePriceQirshPerKg: 2,
            createdByUserId: _owner.id,
            customerId: testCustomer.id,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('sale stores createdBy user identity', () async {
      final fixture = await _fixture();

      final sale = await fixture.sales.createSale(_saleDraft(fixture));

      expect(sale.createdByUserId, _owner.id);
      expect(sale.createdByUserName, _owner.name);
    });

    test('controller allows owner and employee to create sales', () async {
      final ownerFixture = await _fixture();
      final employeeFixture = await _fixture();

      expect(
        await ownerFixture.controller.createSale(
          user: _owner,
          productId: ownerFixture.product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          customerId: ownerFixture.customer.id,
        ),
        isTrue,
      );
      expect(
        await employeeFixture.controller.createSale(
          user: _employee,
          productId: employeeFixture.product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
          customerId: employeeFixture.customer.id,
        ),
        isTrue,
      );
    });

    test('controller rejects inactive or invalid user', () async {
      final fixture = await _fixture();

      expect(
        await fixture.controller.createSale(
          user: _inactiveOwner,
          productId: fixture.product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
        ),
        isFalse,
      );
      expect(
        await fixture.controller.createSale(
          user: _invalidUser,
          productId: fixture.product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 700,
        ),
        isFalse,
      );
    });
  });

  group('Sales UI', () {
    testWidgets('sales create action visible for owner and employee',
        (tester) async {
      final ownerAuth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final ownerFixture = await _fixture();

      await tester.pumpWidget(
        _salesHarness(auth: ownerAuth, controller: ownerFixture.controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('تسجيل فاتورة بيع'), findsOneWidget);

      final employeeAuth = await _signedInController(
        phone: '01100000000',
        password: 'employee123',
      );
      final employeeFixture = await _fixture();

      await tester.pumpWidget(
        _salesHarness(
          auth: employeeAuth,
          controller: employeeFixture.controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تسجيل فاتورة بيع'), findsOneWidget);
    });

    testWidgets('sales screen shows selectable product cards', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();

      await tester.pumpWidget(
        _salesHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('اختر صنف البيع'), findsOneWidget);
      expect(find.text('المخزون الحالي: 1000 كجم'), findsOneWidget);
      expect(find.text('بيع هذا الصنف'), findsOneWidget);
    });
    testWidgets('sales form shows required Arabic labels', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();

      await tester.pumpWidget(
        _salesHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل فاتورة بيع'));
      await tester.pumpAndSettle();

      expect(find.text('اختر العميل *'), findsOneWidget);
      expect(find.text('الصنف'), findsOneWidget);
      expect(find.text('الكمية (كجم)'), findsOneWidget);
      expect(find.text('السعر / كجم'), findsOneWidget);
      expect(find.text('الإجمالي: -'), findsOneWidget);
      expect(find.text('حفظ الفاتورة'), findsOneWidget);
    });

    testWidgets('owner sees sale cancellation action', (tester) async {
      final auth =
          await _signedInController(phone: '01000000000', password: 'owner123');
      final fixture = await _fixture();
      await fixture.sales.createSale(_saleDraft(fixture));
      await fixture.controller.load(_owner);

      await tester.pumpWidget(
        _salesHarness(auth: auth, controller: fixture.controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('إلغاء مستند البيع'), findsOneWidget);
    });
  });
}

SaleDraft _saleDraft(
  _SalesFixture fixture, {
  String? productId,
  int quantityKg = 250,
  int price = 700,
  String? customerId,
}) {
  return SaleDraft(
    productId: productId ?? fixture.product.id,
    quantityKg: quantityKg,
    salePriceQirshPerKg: price,
    createdByUserId: _owner.id,
    createdByUserName: _owner.name,
    notes: 'بيع حبوب',
    customerId: customerId ?? fixture.customer.id,
  );
}

ProductDraft _productDraft() {
  return const ProductDraft(
    name: 'قمح',
    unit: GrainUnit.kilogram,
  );
}

Future<_SalesFixture> _fixture() async {
  final products = LocalProductRepository();
  final product = await products.createProduct(_productDraft());
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(
    StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 1000,
      createdByUserId: _owner.id,
    ),
  );
  final customers = LocalCustomerRepository();
  final customer = await customers.createCustomer(
    const CustomerDraft(name: 'عميل اختبار', isActive: true),
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  final controller = SaleController(
    saleRepository: sales,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    customerRepository: customers,
  );
  await controller.load(_owner);

  return _SalesFixture(
    products: products,
    inventory: inventory,
    sales: sales,
    controller: controller,
    product: product,
    customer: customer,
  );
}

Widget _salesHarness({
  required AuthController auth,
  required SaleController controller,
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
      home: SalesScreen(controller: controller),
    ),
  );
}

Future<AuthController> _signedInController({
  required String phone,
  required String password,
}) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

class _SalesFixture {
  const _SalesFixture({
    required this.products,
    required this.inventory,
    required this.sales,
    required this.controller,
    required this.product,
    required this.customer,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalSaleRepository sales;
  final SaleController controller;
  final Product product;
  final Customer customer;
}

class _LargeStockInventoryRepository implements InventoryRepository {
  const _LargeStockInventoryRepository(this.productId);

  final String productId;

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) async {
    return StockMovement(
      id: 'movement-id',
      productId: draft.productId,
      movementType: draft.movementType,
      quantityKg: draft.quantityKg,
      createdByUserId: draft.createdByUserId,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    return {productId: 9223372036854775807};
  }

  @override
  Future<int> currentStockKg(String productId) async {
    return 9223372036854775807;
  }

  @override
  Future<bool> hasOpeningBalance(String productId) async {
    return true;
  }

  @override
  Future<List<StockMovement>> listAllMovements() async {
    return const [];
  }

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return const [];
  }
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

final _employee = AppUser(
  id: 'employee-test',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _inactiveOwner = AppUser(
  id: 'inactive-owner',
  name: 'مالك غير نشط',
  phone: '01000000003',
  role: UserRole.owner,
  isActive: false,
  createdAt: _now,
  updatedAt: _now,
);

final _invalidUser = AppUser(
  id: ' ',
  name: 'مستخدم غير صالح',
  phone: '01000000004',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
