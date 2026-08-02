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
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

const _egpMarker = '\u062c.\u0645';
const _rawQirsh = '\u0642\u0631\u0634';

void main() {
  group('Phase 21D final business acceptance', () {
    test(
        'complete grain warehouse workflow keeps pricing stock reports and backups safe',
        () async {
      final fixture = await _seededFixture();

      expect(await fixture.inventory.currentStockKg(fixture.costedProduct.id),
          1000);
      expect(await fixture.inventory.currentStockKg(fixture.noCostProduct.id),
          400);
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(2));
      expect(await fixture.inventory.listAllMovements(), hasLength(2));

      expect(
        () => fixture.sales.createSale(
          _saleDraft(fixture.costedProduct.id,
              quantityKg: 100, price: 799, customerId: _dummyCustomer.id),
        ),
        throwsA(isA<MinimumSalePriceViolation>()),
      );
      expect(await fixture.sales.listSales(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), hasLength(2));
      expect(await fixture.inventory.currentStockKg(fixture.costedProduct.id),
          1000);

      final costedSale = await fixture.sales.createSale(
        _saleDraft(fixture.costedProduct.id,
            quantityKg: 200, price: 900, customerId: _dummyCustomer.id),
      );
      expect(costedSale.totalQirsh, 180000);
      expect(await fixture.inventory.currentStockKg(fixture.costedProduct.id),
          800);

      final completeCostReport = await fixture.reports.dailyActivityReport(
        selectedDate: costedSale.createdAt,
      );
      expect(completeCostReport.totalPurchaseAmountQirsh, 880000);
      expect(completeCostReport.totalSalesAmountQirsh, 180000);
      expect(completeCostReport.estimatedSalesCostQirsh, 130000);
      expect(completeCostReport.estimatedGrossProfitQirsh, 50000);
      expect(completeCostReport.hasCompleteSalesCost, isTrue);
      expect(completeCostReport.hasCompleteStockValuation, isFalse);
      expect(completeCostReport.missingStockCostProductNames,
          contains(fixture.noCostProduct.name));

      final noCostSale = await fixture.sales.createSale(
        _saleDraft(fixture.noCostProduct.id,
            quantityKg: 100, price: 1100, customerId: _dummyCustomer.id),
      );
      expect(noCostSale.totalQirsh, 110000);
      expect(await fixture.inventory.currentStockKg(fixture.noCostProduct.id),
          300);

      final incompleteCostReport = await fixture.reports.dailyActivityReport(
        selectedDate: noCostSale.createdAt,
      );
      expect(incompleteCostReport.totalPurchasedKg, 1400);
      expect(incompleteCostReport.totalSoldKg, 300);
      expect(incompleteCostReport.totalPurchaseAmountQirsh, 880000);
      expect(incompleteCostReport.totalSalesAmountQirsh, 290000);
      expect(incompleteCostReport.estimatedSalesCostQirsh, isNull);
      expect(incompleteCostReport.estimatedGrossProfitQirsh, isNull);
      expect(incompleteCostReport.hasCompleteSalesCost, isFalse);
      expect(incompleteCostReport.missingSalesCostProductNames,
          contains(fixture.noCostProduct.name));
      expect(incompleteCostReport.hasCompleteStockValuation, isFalse);
      expect(incompleteCostReport.missingStockCostProductNames,
          contains(fixture.noCostProduct.name));

      final history = await fixture.history.listHistory();
      expect(history, hasLength(4));
      expect(history.where((entry) => entry.isCancelled), isEmpty);
      expect(history.map((entry) => entry.quantityKg).reduce((a, b) => a + b),
          1700);

      final backup = await fixture.backupExport.createBackup();
      BackupExportValidator.validateJsonText(backup.jsonText);
      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final products = _productJsonByName(decoded);
      expect(products['costed-wheat']!['defaultSalePricePiastersPerKg'], 950);
      expect(products['costed-wheat']!['minimumSalePricePiastersPerKg'], 800);
      expect(products['costed-wheat']!['referenceCostPricePiastersPerKg'], 650);
      expect(
          products['no-cost-corn']!['referenceCostPricePiastersPerKg'], isNull);

      final restored = await _restoreIntoEmpty(backup.jsonText);
      expect(restored.result.success, isTrue);
      expect(await restored.products.listProducts(), hasLength(2));
      expect(await restored.purchases.listPurchaseIntakes(), hasLength(2));
      expect(await restored.sales.listSales(), hasLength(2));
      expect(await restored.history.listHistory(), hasLength(4));
      expect(await restored.inventory.currentStockKg(fixture.costedProduct.id),
          800);
      expect(await restored.inventory.currentStockKg(fixture.noCostProduct.id),
          300);
      final restoredCosted = (await restored.products.listProducts())
          .singleWhere((product) => product.name == 'costed-wheat');
      expect(restoredCosted.defaultSalePricePiastersPerKg, 950);
      expect(restoredCosted.minimumSalePricePiastersPerKg, 800);
      expect(restoredCosted.referenceCostPricePiastersPerKg, 650);

      final oldBackup = jsonDecode(backup.jsonText) as Map<String, Object?>;
      _productJsonByName(oldBackup)['costed-wheat']!
          .remove('referenceCostPricePiastersPerKg');
      final oldRestored = await _restoreIntoEmpty(
        const JsonEncoder.withIndent('  ').convert(oldBackup),
      );
      expect(oldRestored.result.success, isTrue);
      final oldCosted = (await oldRestored.products.listProducts())
          .singleWhere((product) => product.name == 'costed-wheat');
      expect(oldCosted.referenceCostPricePiastersPerKg, isNull);
    });

    testWidgets('normal business UI uses EGP formatting without raw qirsh',
        (tester) async {
      await _setDesktopViewport(tester);
      final fixture = await _seededWidgetFixture(tester);
      await fixture.sales.createSale(
        _saleDraft(fixture.costedProduct.id,
            quantityKg: 100, price: 900, customerId: _dummyCustomer.id),
      );
      final auth = await _signedInController();
      addTearDown(auth.dispose);

      final reportController = ReportController(repository: fixture.reports);
      addTearDown(reportController.dispose);
      await reportController.loadDailyActivity(user: _owner);
      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: ReportsScreen(controller: reportController),
        ),
      );
      await _pumpExpectedState(tester);
      expect(find.textContaining(_egpMarker), findsWidgets);
      expect(find.textContaining(_rawQirsh), findsNothing);

      final productController = ProductController(
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(fixture.products),
        repository: fixture.products,
      );
      addTearDown(productController.dispose);
      await productController.loadProducts(_owner);
      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: ProductsScreen(controller: productController),
        ),
      );
      await _pumpExpectedState(tester);
      expect(find.textContaining(_egpMarker), findsWidgets);
      expect(find.textContaining(_rawQirsh), findsNothing);
    });
  });
}

Future<_Fixture> _seededFixture() async {
  final products = LocalProductRepository();
  final costedProduct = await products.createProduct(
    const ProductDraft(
      name: 'costed-wheat',
      unit: GrainUnit.kilogram,
      defaultSalePricePiastersPerKg: 950,
      minimumSalePricePiastersPerKg: 800,
      referenceCostPricePiastersPerKg: 650,
    ),
  );
  final noCostProduct = await products.createProduct(
    const ProductDraft(
      name: 'no-cost-corn',
      unit: GrainUnit.kilogram,
      defaultSalePricePiastersPerKg: 1100,
      minimumSalePricePiastersPerKg: 850,
    ),
  );
  final suppliers = LocalSupplierRepository();
  final supplier = await suppliers.createSupplier(
    const SupplierDraft(name: 'main-supplier', phone: '01011112222'),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  await purchases.createPurchaseIntake(
    PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: costedProduct.id,
      quantityKg: 1000,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 600,
      createdByUserId: _owner.id,
    ),
  );
  await purchases.createPurchaseIntake(
    PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: noCostProduct.id,
      quantityKg: 400,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 700,
      createdByUserId: _owner.id,
    ),
  );
  final sales = LocalSaleRepository(
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
  final reports = LocalReportRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    inventoryRepository: inventory,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
  );
  final backupExport = BackupExportService(
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    now: () => DateTime(2026, 7, 6, 12),
  );

  return _Fixture(
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    purchases: purchases,
    sales: sales,
    history: history,
    reports: reports,
    backupExport: backupExport,
    costedProduct: costedProduct,
    noCostProduct: noCostProduct,
  );
}

Future<_Fixture> _seededWidgetFixture(WidgetTester tester) async {
  final fixture = await tester.runAsync(_seededFixture);
  if (fixture == null) {
    throw StateError('The widget fixture did not initialize.');
  }
  return fixture;
}

final _dummyCustomer = Customer(
  id: 'dummy-customer',
  name: 'عميل',
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

SaleDraft _saleDraft(
  String productId, {
  required int quantityKg,
  required int price,
  String? customerId,
}) {
  return SaleDraft(
    productId: productId,
    quantityKg: quantityKg,
    salePriceQirshPerKg: price,
    createdByUserId: _owner.id,
    createdByUserName: _owner.name,
    customerId: customerId,
  );
}

Map<String, Map<String, Object?>> _productJsonByName(
  Map<String, Object?> decoded,
) {
  final data = decoded['data'] as Map<String, Object?>;
  final products = data['products'] as List<Object?>;
  return {
    for (final product in products.cast<Map<String, Object?>>())
      product['name']! as String: product,
  };
}

Future<_RestoreOutcome> _restoreIntoEmpty(String jsonText) async {
  final products = LocalProductRepository();
  final suppliers = LocalSupplierRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final sales = LocalSaleRepository(
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
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
  ).restoreToEmpty(user: _owner, jsonText: jsonText);

  return _RestoreOutcome(
    result: result,
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    purchases: purchases,
    sales: sales,
    history: history,
  );
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

Future<void> _setDesktopViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpExpectedState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _Fixture {
  const _Fixture({
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.reports,
    required this.backupExport,
    required this.costedProduct,
    required this.noCostProduct,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final LocalReportRepository reports;
  final BackupExportService backupExport;
  final Product costedProduct;
  final Product noCostProduct;
}

class _RestoreOutcome {
  const _RestoreOutcome({
    required this.result,
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
  });

  final BackupRestoreResult result;
  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
}

final _now = DateTime(2026, 7, 6);

final _owner = AppUser(
  id: 'owner-phase21d',
  name: 'owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
