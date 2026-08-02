import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';
import 'package:grain_warehouse_erp_lite/features/sales/sales_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 21B pricing, cost, minimum, UI acceptance', () {
    test('product cost field is optional and stored when provided', () async {
      final repository = LocalProductRepository();

      final withoutCost = await repository.createProduct(
        _productDraft(name: 'قمح بدون تكلفة', referenceCost: null),
      );
      final withCost = await repository.createProduct(
        _productDraft(name: 'قمح بتكلفة', referenceCost: 820),
      );

      expect(withoutCost.referenceCostPricePiastersPerKg, isNull);
      expect(withCost.referenceCostPricePiastersPerKg, 820);
    });

    test('invalid reference cost is rejected', () async {
      final repository = LocalProductRepository();

      expect(
        () => repository.createProduct(
          _productDraft(name: 'تكلفة غير صالحة', referenceCost: 0),
        ),
        throwsArgumentError,
      );
    });

    test('money parser accepts pounds and formatter displays EGP', () {
      expect(MoneyUtils.parseEgpToPiasters('12.50', allowZero: false), 1250);
      expect(MoneyUtils.parseEgpToPiasters('١٢٫٥٠', allowZero: false), 1250);
      expect(MoneyUtils.formatPiastersAsEgp(1250), '12.50 ج.م');
      expect(MoneyUtils.formatPiastersAsEgpNumber(1250), '12.50');
    });

    test('sale below minimum is rejected before stock movement', () async {
      final fixture = await _fixture(minimumSalePrice: 900);

      expect(
        () => fixture.sales.createSale(_saleDraft(fixture, price: 899)),
        throwsA(isA<MinimumSalePriceViolation>()),
      );
      expect(await fixture.sales.listSales(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), hasLength(1));
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 1000);

      final sale = await fixture.sales.createSale(
        _saleDraft(fixture, price: 900),
      );
      expect(sale.salePriceQirshPerKg, 900);
      expect(await fixture.sales.listSales(), hasLength(1));
      expect(await fixture.inventory.listAllMovements(), hasLength(2));
    });

    test('backup exports cost and restore keeps cost or old null', () async {
      final fixture = await _fixture(referenceCost: 760);
      final backup = await BackupExportService(
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        inventoryRepository: fixture.inventory,
        supplierRepository: fixture.suppliers,
        purchaseRepository: fixture.purchases,
        saleRepository: fixture.sales,
        documentHistoryRepository: fixture.history,
        now: () => DateTime(2026, 7, 6, 10),
      ).createBackup();

      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final productJson = _firstProductJson(decoded);
      expect(productJson['referenceCostPricePiastersPerKg'], 760);

      final restored = await _restoreIntoEmpty(backup.jsonText);
      expect(restored.result.success, isTrue);
      expect(
        (await restored.products.listProducts())
            .single
            .referenceCostPricePiastersPerKg,
        760,
      );

      final oldBackup = jsonDecode(backup.jsonText) as Map<String, Object?>;
      _firstProductJson(oldBackup).remove('referenceCostPricePiastersPerKg');
      final oldRestored = await _restoreIntoEmpty(
        const JsonEncoder.withIndent('  ').convert(oldBackup),
      );
      expect(oldRestored.result.success, isTrue);
      expect(
        (await oldRestored.products.listProducts())
            .single
            .referenceCostPricePiastersPerKg,
        isNull,
      );

      final invalidBackup = jsonDecode(backup.jsonText) as Map<String, Object?>;
      _firstProductJson(invalidBackup)['referenceCostPricePiastersPerKg'] =
          'bad-cost';
      final invalidRestored = await _restoreIntoEmpty(
        const JsonEncoder.withIndent('  ').convert(invalidBackup),
      );
      expect(invalidRestored.result.success, isFalse);
    });

    testWidgets('forms show EGP labels and product cost field', (tester) async {
      final auth = await _signedInController();
      final fixture = await _fixture();

      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: ProductsScreen(
            controller: ProductController(
              productCatalogReadRepository:
                  ProductCatalogReadRepositoryTestAdapter(fixture.products),
              repository: fixture.products,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صنف حبوب'));
      await tester.pumpAndSettle();
      expect(
          find.text('السعر الافتراضي بالجنيه / كجم اختياري'), findsOneWidget);
      expect(
          find.text('الحد الأدنى للبيع بالجنيه / كجم اختياري'), findsOneWidget);
      expect(find.text('سعر التكلفة بالجنيه / كجم اختياري'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      await fixture.saleController.load(_owner);
      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: SalesScreen(controller: fixture.saleController),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل فاتورة بيع'));
      await tester.pumpAndSettle();
      expect(find.text('السعر / كجم'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      await fixture.purchaseController.load(_owner);
      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: PurchasesScreen(controller: fixture.purchaseController),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل استلام حبوب'));
      await tester.pumpAndSettle();
      expect(find.text('سعر الشراء بالجنيه / كجم'), findsOneWidget);
    });
  });
}

ProductDraft _productDraft({
  required String name,
  int? minimumSalePrice = 700,
  int? referenceCost,
}) {
  return ProductDraft(
    name: name,
    unit: GrainUnit.kilogram,
    defaultSalePricePiastersPerKg: 900,
    minimumSalePricePiastersPerKg: minimumSalePrice,
    referenceCostPricePiastersPerKg: referenceCost,
  );
}

SaleDraft _saleDraft(_Fixture fixture,
    {required int price, String? customerId}) {
  return SaleDraft(
    productId: fixture.product.id,
    quantityKg: 100,
    salePriceQirshPerKg: price,
    createdByUserId: _owner.id,
    customerId: customerId ?? fixture.customer.id,
  );
}

Future<_Fixture> _fixture({
  int? minimumSalePrice = 700,
  int? referenceCost,
}) async {
  final products = LocalProductRepository();
  final product = await products.createProduct(
    _productDraft(
      name: 'قمح',
      minimumSalePrice: minimumSalePrice,
      referenceCost: referenceCost,
    ),
  );
  final suppliers = LocalSupplierRepository();
  await suppliers.createSupplier(const SupplierDraft(name: 'مورد رئيسي'));
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
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final history = LocalDocumentHistoryRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
  );
  final saleController = SaleController(
    saleRepository: sales,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    customerRepository: customers,
  );
  final purchaseController = PurchaseController(
    purchaseRepository: purchases,
    supplierRepository: suppliers,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
  );

  return _Fixture(
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    sales: sales,
    purchases: purchases,
    history: history,
    saleController: saleController,
    purchaseController: purchaseController,
    product: product,
    customer: customer,
  );
}

Map<String, Object?> _firstProductJson(Map<String, Object?> decoded) {
  final data = decoded['data'] as Map<String, Object?>;
  final products = data['products'] as List<Object?>;
  return products.first as Map<String, Object?>;
}

Future<_RestoreOutcome> _restoreIntoEmpty(String jsonText) async {
  final products = LocalProductRepository();
  final suppliers = LocalSupplierRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final history = LocalDocumentHistoryRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
  );

  final result = await BackupRestoreService(
    productRepository: products,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
  ).restoreToEmpty(user: _owner, jsonText: jsonText);

  return _RestoreOutcome(result: result, products: products);
}

Widget _harness({required AuthController auth, required Widget child}) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: child,
    ),
  );
}

Future<AuthController> _signedInController() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

class _Fixture {
  const _Fixture({
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.sales,
    required this.purchases,
    required this.history,
    required this.saleController,
    required this.purchaseController,
    required this.product,
    required this.customer,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalSaleRepository sales;
  final LocalPurchaseRepository purchases;
  final LocalDocumentHistoryRepository history;
  final SaleController saleController;
  final PurchaseController purchaseController;
  final Product product;
  final Customer customer;
}

class _RestoreOutcome {
  const _RestoreOutcome({required this.result, required this.products});

  final BackupRestoreResult result;
  final LocalProductRepository products;
}

final _now = DateTime(2026, 7, 6);

final _owner = AppUser(
  id: 'owner-phase21b',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
