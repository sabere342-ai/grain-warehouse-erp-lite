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
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_controller.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/products/products_screen.dart';
import 'package:grain_warehouse_erp_lite/features/reports/reports_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 21C profit and stock valuation reports', () {
    test('product with reference cost calculates sale cost and gross profit',
        () async {
      final fixture = await _fixture(referenceCost: 700);
      final sale = await fixture.sales.createSale(
        _saleDraft(fixture.product.id,
            price: 900, customerId: _testCustomer.id),
      );

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: sale.createdAt,
      );

      expect(report.totalSalesAmountQirsh, 90000);
      expect(report.estimatedSalesCostQirsh, 70000);
      expect(report.estimatedGrossProfitQirsh, 20000);
      expect(report.hasCompleteSalesCost, isTrue);
    });

    test('product without reference cost keeps sales visible and hides profit',
        () async {
      final fixture = await _fixture(referenceCost: null);
      final sale = await fixture.sales.createSale(
        _saleDraft(fixture.product.id,
            price: 900, customerId: _testCustomer.id),
      );

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: sale.createdAt,
      );

      expect(report.totalSalesAmountQirsh, 90000);
      expect(report.estimatedSalesCostQirsh, isNull);
      expect(report.estimatedGrossProfitQirsh, isNull);
      expect(report.hasCompleteSalesCost, isFalse);
      expect(
          report.missingSalesCostProductNames, contains(fixture.product.name));
    });

    test('stock valuation uses reference cost and warns for missing cost',
        () async {
      final fixture = await _fixture(referenceCost: 700);
      final noCostProduct = await fixture.products.createProduct(
        _productDraft(name: 'ذرة بدون تكلفة', referenceCost: null),
      );
      await fixture.inventory.createMovement(
        StockMovementDraft(
          productId: noCostProduct.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 300,
          createdByUserId: _owner.id,
        ),
      );

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: DateTime.now(),
      );

      expect(report.estimatedStockValueQirsh, isNull);
      expect(report.hasCompleteStockValuation, isFalse);
      expect(report.missingStockCostProductNames, contains(noCostProduct.name));
    });

    testWidgets('report and product UI use EGP formatting without raw qirsh',
        (tester) async {
      final auth = await _signedInController();
      final fixture = await _fixture(referenceCost: null);
      await fixture.sales.createSale(_saleDraft(fixture.product.id,
          price: 900, customerId: _testCustomer.id));

      await tester.pumpWidget(
        _harness(
          auth: auth,
          child: ReportsScreen(
            controller: ReportController(repository: fixture.reports),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إجمالي المبيعات'), findsOneWidget);
      expect(find.text('مؤشر هامش مرجعي غير محاسبي'), findsOneWidget);
      expect(find.text('تنبيه نقص التكلفة المرجعية'), findsOneWidget);
      expect(find.textContaining('ج.م'), findsWidgets);
      expect(find.textContaining('قرش'), findsNothing);

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

      expect(find.textContaining('بدون تكلفة مرجعية'), findsOneWidget);
      expect(find.textContaining('ج.م'), findsWidgets);
      expect(find.textContaining('قرش'), findsNothing);
    });

    test('minimum price enforcement and old backup compatibility still pass',
        () async {
      final fixture = await _fixture(referenceCost: 700);

      expect(
        () => fixture.sales.createSale(_saleDraft(fixture.product.id,
            price: 699, customerId: _testCustomer.id)),
        throwsA(isA<MinimumSalePriceViolation>()),
      );
      expect(await fixture.sales.listSales(), isEmpty);

      final backup = await fixture.backupExport.createBackup();
      final oldBackup = jsonDecode(backup.jsonText) as Map<String, Object?>;
      _firstProductJson(oldBackup).remove('referenceCostPricePiastersPerKg');

      final restored = await _restoreIntoEmpty(
        const JsonEncoder.withIndent('  ').convert(oldBackup),
      );

      expect(restored.result.success, isTrue);
      expect(
        (await restored.products.listProducts())
            .single
            .referenceCostPricePiastersPerKg,
        isNull,
      );
    });
  });
}

Future<_Fixture> _fixture({required int? referenceCost}) async {
  final products = LocalProductRepository();
  final product = await products.createProduct(
    _productDraft(name: 'قمح', referenceCost: referenceCost),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  await inventory.createMovement(
    StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 1000,
      createdByUserId: _owner.id,
    ),
  );
  final suppliers = LocalSupplierRepository();
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
    now: () => DateTime(2026, 7, 6, 10),
  );

  return _Fixture(
    products: products,
    inventory: inventory,
    sales: sales,
    reports: reports,
    backupExport: backupExport,
    product: product,
  );
}

ProductDraft _productDraft({
  required String name,
  required int? referenceCost,
}) {
  return ProductDraft(
    name: name,
    unit: GrainUnit.kilogram,
    defaultSalePricePiastersPerKg: 900,
    minimumSalePricePiastersPerKg: 700,
    referenceCostPricePiastersPerKg: referenceCost,
  );
}

SaleDraft _saleDraft(String productId,
    {required int price, String? customerId}) {
  return SaleDraft(
    productId: productId,
    quantityKg: 100,
    salePriceQirshPerKg: price,
    createdByUserId: _owner.id,
    createdByUserName: _owner.name,
    customerId: customerId,
  );
}

final _testCustomer = Customer(
  id: 'test-customer-21c',
  name: 'عميل',
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

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

class _Fixture {
  const _Fixture({
    required this.products,
    required this.inventory,
    required this.sales,
    required this.reports,
    required this.backupExport,
    required this.product,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalSaleRepository sales;
  final LocalReportRepository reports;
  final BackupExportService backupExport;
  final Product product;
}

class _RestoreOutcome {
  const _RestoreOutcome({required this.result, required this.products});

  final BackupRestoreResult result;
  final LocalProductRepository products;
}

final _now = DateTime(2026, 7, 6);

final _owner = AppUser(
  id: 'owner-phase21c',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
