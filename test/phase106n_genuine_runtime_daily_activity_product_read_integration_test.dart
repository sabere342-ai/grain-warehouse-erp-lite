import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';

final _selectedDate = DateTime(2026, 7, 30, 16);
final _start = DateTime(2026, 7, 30);
final _end = DateTime(2026, 7, 31);
final _beforeDay = DateTime(2026, 7, 29, 8);
final _afterDay = DateTime(2026, 7, 31, 8);

void main() {
  group('Phase 106N genuine runtime daily activity product read', () {
    test(
        'full report reads the real Drift catalog and computes exact balances '
        'and costs without the legacy surface', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);

      await _seedProduct(
        fixture.database,
        id: 'prd-106n-active',
        name: 'Active wheat',
        isActive: true,
        referenceCost: 12345,
        createdAt: DateTime(2026, 7, 30, 8),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106n-inactive',
        name: 'Archived barley',
        isActive: false,
        referenceCost: 6789,
        createdAt: DateTime(2026, 7, 30, 9),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106n-no-movements',
        name: 'No movements',
        isActive: true,
        referenceCost: null,
        createdAt: DateTime(2026, 7, 30, 10),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106n-null-cost',
        name: 'Uncosted corn',
        isActive: true,
        referenceCost: null,
        createdAt: DateTime(2026, 7, 30, 10),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-active-prev',
        productId: 'prd-106n-active',
        type: StockMovementType.openingBalance,
        quantityKg: 100,
        createdAt: _beforeDay,
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-active-open',
        productId: 'prd-106n-active',
        type: StockMovementType.openingBalance,
        quantityKg: 10,
        createdAt: DateTime(2026, 7, 30, 9),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-active-sale',
        productId: 'prd-106n-active',
        type: StockMovementType.sale,
        quantityKg: 3,
        createdAt: DateTime(2026, 7, 30, 10),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-active-voided',
        productId: 'prd-106n-active',
        type: StockMovementType.sale,
        quantityKg: 99,
        createdAt: DateTime(2026, 7, 30, 10, 30),
        isVoided: true,
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-inactive-inc',
        productId: 'prd-106n-inactive',
        type: StockMovementType.manualIncrease,
        quantityKg: 4,
        createdAt: DateTime(2026, 7, 30, 11),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-inactive-dec',
        productId: 'prd-106n-inactive',
        type: StockMovementType.manualDecrease,
        quantityKg: 1,
        createdAt: DateTime(2026, 7, 30, 11, 30),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-null-open',
        productId: 'prd-106n-null-cost',
        type: StockMovementType.openingBalance,
        quantityKg: 5,
        createdAt: DateTime(2026, 7, 30, 12),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-null-next',
        productId: 'prd-106n-null-cost',
        type: StockMovementType.manualDecrease,
        quantityKg: 5,
        createdAt: _afterDay,
      );
      await _seedSale(
        fixture.database,
        id: 'sal-106n-active',
        productId: 'prd-106n-active',
        quantityKg: 2,
        salePriceQirshPerKg: 20000,
        totalQirsh: 40000,
        createdAt: DateTime(2026, 7, 30, 10, 15),
      );

      final productsBefore = await _productSnapshot(fixture.database);
      final movementsBefore = await _movementSnapshot(fixture.database);
      final salesBefore = await _saleSnapshot(fixture.database);

      final report = await fixture.report.dailyActivityReport(
        selectedDate: _selectedDate,
      );

      expect(fixture.legacyProducts.listProductCalls, 0);
      expect(fixture.catalog, isA<DriftProductCatalogReadRepository>());
      expect(fixture.inventory, isA<DriftInventoryRepository>());
      expect(report.start, _start);
      expect(report.end, _end);
      expect(
        report.stockBalances
            .map((balance) => balance.productId)
            .toList(growable: false),
        [
          'prd-106n-active',
          'prd-106n-inactive',
          'prd-106n-no-movements',
          'prd-106n-null-cost',
        ],
      );
      expect(
        report.stockBalances.map((balance) => balance.productName).toList(),
        ['Active wheat', 'Archived barley', 'No movements', 'Uncosted corn'],
      );
      expect(
        report.stockBalances.map((balance) => balance.quantityKg).toList(),
        [107, 3, 0, 0],
      );
      expect(report.totalPurchasedKg, 0);
      expect(report.totalSoldKg, 2);
      expect(report.totalSalesAmountQirsh, 40000);
      expect(report.estimatedSalesCostQirsh, 24690);
      expect(report.estimatedGrossProfitQirsh, 15310);
      expect(report.estimatedStockValueQirsh, 1341282);
      expect(report.hasCompleteSalesCost, isTrue);
      expect(report.hasCompleteStockValuation, isTrue);
      expect(report.missingSalesCostProductNames, isEmpty);
      expect(report.missingStockCostProductNames, isEmpty);
      expect(report.stockMovementCount, 6);
      expect(
        report.recentMovements.map((movement) => movement.id).toList(),
        [
          'mov-106n-null-open',
          'mov-106n-inactive-dec',
          'mov-106n-inactive-inc',
          'mov-106n-active-voided',
          'mov-106n-active-sale',
          'mov-106n-active-open',
        ],
      );
      expect(
        report.recentMovements.map((movement) => movement.productName).toList(),
        [
          'Uncosted corn',
          'Archived barley',
          'Archived barley',
          'Active wheat',
          'Active wheat',
          'Active wheat',
        ],
      );
      final recentIds =
          report.recentMovements.map((movement) => movement.id).toList();
      expect(recentIds, isNot(contains('mov-106n-active-prev')));
      expect(recentIds, isNot(contains('mov-106n-null-next')));
      expect(await fixture.inventory.allProductBalancesKg(), {
        'prd-106n-active': 107,
        'prd-106n-inactive': 3,
        'prd-106n-no-movements': 0,
        'prd-106n-null-cost': 0,
      });
      expect(await _productSnapshot(fixture.database), productsBefore);
      expect(await _movementSnapshot(fixture.database), movementsBefore);
      expect(await _saleSnapshot(fixture.database), salesBefore);
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('null reference cost stays null through the genuine path', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      await _seedProduct(
        fixture.database,
        id: 'prd-106n-uncosted',
        name: 'Uncosted corn',
        isActive: true,
        referenceCost: null,
        createdAt: DateTime(2026, 7, 30, 8),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-uncosted-open',
        productId: 'prd-106n-uncosted',
        type: StockMovementType.openingBalance,
        quantityKg: 5,
        createdAt: DateTime(2026, 7, 30, 9),
      );

      final report = await fixture.report.dailyActivityReport(
        selectedDate: _selectedDate,
      );

      expect(report.stockBalances.single.productName, 'Uncosted corn');
      expect(report.stockBalances.single.quantityKg, 5);
      expect(report.estimatedStockValueQirsh, isNull);
      expect(report.hasCompleteStockValuation, isFalse);
      expect(report.missingStockCostProductNames, ['Uncosted corn']);
      expect(report.estimatedSalesCostQirsh, 0);
      expect(report.hasCompleteSalesCost, isTrue);
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('empty SQLite database produces the correct report without crash',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);

      final report = await fixture.report.dailyActivityReport(
        selectedDate: _selectedDate,
      );

      expect(report.start, _start);
      expect(report.end, _end);
      expect(report.stockBalances, isEmpty);
      expect(report.recentMovements, isEmpty);
      expect(report.stockMovementCount, 0);
      expect(report.totalPurchasedKg, 0);
      expect(report.totalSoldKg, 0);
      expect(report.estimatedSalesCostQirsh, 0);
      expect(report.estimatedStockValueQirsh, 0);
      expect(report.hasCompleteSalesCost, isTrue);
      expect(report.hasCompleteStockValuation, isTrue);
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('a re-read reflects later SQLite rows without any hidden cache',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      await _seedProduct(
        fixture.database,
        id: 'prd-106n-fresh',
        name: 'Fresh grain',
        isActive: true,
        referenceCost: 321,
        createdAt: DateTime(2026, 7, 30, 8),
      );
      await _seedMovement(
        fixture.database,
        id: 'mov-106n-fresh-first',
        productId: 'prd-106n-fresh',
        type: StockMovementType.openingBalance,
        quantityKg: 8,
        createdAt: DateTime(2026, 7, 30, 9),
      );

      final first = await fixture.report.dailyActivityReport(
        selectedDate: _selectedDate,
      );
      expect(first.stockBalances.single.quantityKg, 8);
      expect(first.stockBalances.single.productName, 'Fresh grain');

      await _seedMovement(
        fixture.database,
        id: 'mov-106n-fresh-second',
        productId: 'prd-106n-fresh',
        type: StockMovementType.sale,
        quantityKg: 3,
        createdAt: DateTime(2026, 7, 30, 10),
      );
      await fixture.database.customStatement(
        "UPDATE products SET name = 'Renamed grain' "
        "WHERE id = 'prd-106n-fresh'",
      );

      final second = await fixture.report.dailyActivityReport(
        selectedDate: _selectedDate,
      );
      expect(second.stockBalances.single.quantityKg, 5);
      expect(second.stockBalances.single.productName, 'Renamed grain');
      expect(second.estimatedStockValueQirsh, 1605);
      expect(fixture.legacyProducts.listProductCalls, 0);
    });

    test('genuine AppRepositories composition runs the report on SQLite',
        () async {
      final database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
      addTearDown(AppRepositories.close);
      await _seedProduct(
        database,
        id: 'prd-106n-production',
        name: 'Production sentinel',
        isActive: false,
        referenceCost: 54321,
        defaultSalePrice: 60000,
        minimumSalePrice: 58000,
        createdAt: DateTime(2026, 7, 30, 8),
      );
      await _seedMovement(
        database,
        id: 'mov-106n-production-open',
        productId: 'prd-106n-production',
        type: StockMovementType.openingBalance,
        quantityKg: 3,
        createdAt: DateTime(2026, 7, 30, 9),
      );

      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
      expect(
        AppRepositories.inventoryRepository,
        isA<DriftInventoryRepository>(),
      );

      final report = await AppRepositories.reportRepository.dailyActivityReport(
        selectedDate: _selectedDate,
      );

      expect(report.stockBalances.single.productName, 'Production sentinel');
      expect(report.stockBalances.single.quantityKg, 3);
      expect(report.estimatedStockValueQirsh, 162963);
      expect(report.hasCompleteStockValuation, isTrue);
    });
  });

  test(
      'static guard confines the daily activity path to the catalog read '
      'boundary', () {
    final reportSource =
        File('lib/core/reports/report_repository.dart').readAsStringSync();
    expect(reportSource, contains('ProductCatalogReadRepository'));
    expect(reportSource, isNot(contains('product_repository.dart')));
    expect(reportSource, isNot(contains('ProductRepository')));
    expect(reportSource, isNot(contains('.listProducts(')));
    final dailyActivityBody = _methodBody(
      reportSource,
      'Future<DailyActivityReport> dailyActivityReport(',
    );
    expect(dailyActivityBody, contains('_productCatalogReadRepository'));
    expect(dailyActivityBody, isNot(contains('_productRepository')));

    final inventorySource =
        File('lib/core/inventory/drift_inventory_repository.dart')
            .readAsStringSync();
    final balancesBody = _methodBody(
      inventorySource,
      'Future<Map<String, int>> allProductBalancesKg(',
    );
    expect(balancesBody, contains('_productCatalogReadRepository'));
    expect(balancesBody, isNot(contains('_productRepository')));
    expect(balancesBody, isNot(contains('currentStockKg(')));

    final catalogSource =
        File('lib/core/catalog/drift_product_catalog_read_repository.dart')
            .readAsStringSync();
    expect(catalogSource, contains('implements ProductCatalogReadRepository'));
    expect(catalogSource, contains('_database.products'));
    final catalogBody = _methodBody(catalogSource, 'listProductCatalog({');
    expect(catalogBody, contains('OrderingTerm.asc(products.createdAt)'));
    expect(catalogBody, contains('OrderingTerm.asc(products.id)'));
    expect(catalogBody, contains('includeInactive'));

    final compositionSource =
        File('lib/app/app_repositories.dart').readAsStringSync();
    expect(
      compositionSource,
      contains(
        '_productCatalogReadRepository = DriftProductCatalogReadRepository(',
      ),
    );
  });
}

final class _Fixture {
  _Fixture._(
    this.database,
    this.legacyProducts,
    this.catalog,
    this.inventory,
    this.report,
  );

  factory _Fixture.open() {
    final database = openInMemoryTestDatabase();
    final legacyProducts = _ThrowingProductRepository();
    final catalog = DriftProductCatalogReadRepository(database);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: catalog,
    );
    final purchaseRepository = DriftPurchaseRepository(
      database,
      supplierRepository: DriftSupplierRepository(database),
      productRepository: legacyProducts,
      inventoryRepository: inventory,
    );
    final saleRepository = DriftSaleRepository(
      database,
      productRepository: legacyProducts,
      inventoryRepository: inventory,
    );
    final report = LocalReportRepository(
      purchaseRepository: purchaseRepository,
      saleRepository: saleRepository,
      inventoryRepository: inventory,
      productCatalogReadRepository: catalog,
      expenseRepository: DriftExpenseRepository(database),
    );
    return _Fixture._(
      database,
      legacyProducts,
      catalog,
      inventory,
      report,
    );
  }

  final db.FoundationDatabase database;
  final _ThrowingProductRepository legacyProducts;
  final DriftProductCatalogReadRepository catalog;
  final DriftInventoryRepository inventory;
  final LocalReportRepository report;

  Future<void> close() => database.close();
}

final class _ThrowingProductRepository implements ProductRepository {
  int listProductCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) {
    listProductCalls++;
    throw StateError('Phase 106N legacy listProducts sentinel');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnsupportedError('Phase 106N read-only legacy sentinel');

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      throw UnsupportedError('Phase 106N read-only legacy sentinel');

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) =>
      throw UnsupportedError('Phase 106N read-only legacy sentinel');
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required bool isActive,
  required int? referenceCost,
  required DateTime createdAt,
  int? defaultSalePrice,
  int? minimumSalePrice,
}) async {
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value('code-$id'),
          normalizedCode: Value('code-$id'.toLowerCase()),
          unit: GrainUnit.kilogram.name,
          isActive: isActive,
          referenceCostPricePiastersPerKg: Value(referenceCost),
          defaultSalePricePiastersPerKg: Value(defaultSalePrice),
          minimumSalePricePiastersPerKg: Value(minimumSalePrice),
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
}

Future<void> _seedMovement(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required StockMovementType type,
  required int quantityKg,
  required DateTime createdAt,
  bool isVoided = false,
}) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: id,
          productId: productId,
          movementType: type.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106n',
          createdAt: createdAt,
          isVoided: Value(isVoided),
        ),
      );
}

Future<void> _seedSale(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required int quantityKg,
  required int salePriceQirshPerKg,
  required int totalQirsh,
  required DateTime createdAt,
}) async {
  await database.into(database.sales).insert(
        db.SalesCompanion.insert(
          id: id,
          productId: productId,
          quantityKg: quantityKg,
          salePriceQirshPerKg: salePriceQirshPerKg,
          totalQirsh: totalQirsh,
          createdByUserId: 'phase-106n',
          createdAt: createdAt,
          stockMovementId: '$id-movement',
          paymentMode: 'cash',
          itemsJson: jsonEncode([
            {
              'productId': productId,
              'quantityKg': quantityKg,
              'salePriceQirshPerKg': salePriceQirshPerKg,
              'lineTotalQirsh': totalQirsh,
            },
          ]),
          paymentAllocationsJson: jsonEncode([]),
        ),
      );
}

Future<List<Object>> _productSnapshot(db.FoundationDatabase database) async {
  final rows = await (database.select(database.products)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return rows
      .map<Object>(
        (row) => (
          row.id,
          row.name,
          row.normalizedName,
          row.code,
          row.normalizedCode,
          row.unit,
          row.isActive,
          row.defaultSalePricePiastersPerKg,
          row.minimumSalePricePiastersPerKg,
          row.referenceCostPricePiastersPerKg,
          row.notes,
          row.createdAt,
          row.updatedAt,
        ),
      )
      .toList(growable: false);
}

Future<List<Object>> _movementSnapshot(db.FoundationDatabase database) async {
  final rows = await (database.select(database.inventoryMovements)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return rows
      .map<Object>(
        (row) => (
          row.id,
          row.productId,
          row.movementType,
          row.quantityKg,
          row.createdByUserId,
          row.createdAt,
          row.note,
          row.isVoided,
          row.reversedMovementId,
          row.originalDocumentId,
        ),
      )
      .toList(growable: false);
}

Future<List<Object>> _saleSnapshot(db.FoundationDatabase database) async {
  final rows = await (database.select(database.sales)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  return rows
      .map<Object>(
        (row) => (
          row.id,
          row.productId,
          row.quantityKg,
          row.salePriceQirshPerKg,
          row.totalQirsh,
          row.createdByUserId,
          row.createdAt,
          row.stockMovementId,
          row.paymentMode,
          row.customerId,
          row.itemsJson,
          row.paymentAllocationsJson,
        ),
      )
      .toList(growable: false);
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('Missing method: $signature');
  final asyncMarker = source.indexOf('async {', start);
  if (asyncMarker < 0) throw StateError('Missing async body: $signature');
  final openBrace = asyncMarker + 'async '.length;
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $signature');
}
