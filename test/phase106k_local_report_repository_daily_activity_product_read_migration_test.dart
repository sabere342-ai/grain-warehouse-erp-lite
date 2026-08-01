import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

const _repositoryPath = 'lib/core/reports/report_repository.dart';
final _selectedDate = DateTime(2026, 7, 30, 16);
final _start = DateTime(2026, 7, 30);
final _morning = DateTime(2026, 7, 30, 9);
final _evening = DateTime(2026, 7, 30, 18);

void main() {
  test('daily activity uses only the injected catalog read boundary', () {
    final source = File(_repositoryPath).readAsStringSync();
    final implementation =
        source.substring(source.indexOf('class LocalReportRepository'));
    final body = _methodBody(
      implementation,
      'Future<DailyActivityReport> dailyActivityReport(',
    );

    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('ProductRepository')));
    expect(body, contains('_productCatalogReadRepository.listProductCatalog('));
    expect(_occurrences(body, '.listProductCatalog('), 1);
    expect(body, contains('includeInactive: true'));
    expect(body, isNot(contains('.listProducts(')));
    expect(body, isNot(contains('try {')));
    expect(body, isNot(contains('catch (')));
  });

  test(
      'inactive product, exact piaster cost, totals, dates, and ordering survive',
      () async {
    final catalog = _Catalog([
      _product(
        'inactive-wheat',
        'Inactive wheat',
        isActive: false,
        referenceCost: 12347,
      ),
    ]);
    final purchases = _Purchases([
      PurchaseIntake(
        id: 'purchase-1',
        supplierId: 'supplier-1',
        productId: 'inactive-wheat',
        quantityKg: 5,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 700,
        totalAmountPiasters: 3500,
        createdByUserId: 'phase-106k',
        createdAt: _morning,
        stockMovementId: 'purchase-movement',
      ),
    ]);
    final sales = _Sales([
      SaleRecord(
        id: 'sale-1',
        productId: 'inactive-wheat',
        quantityKg: 3,
        salePriceQirshPerKg: 20000,
        totalQirsh: 60000,
        createdByUserId: 'phase-106k',
        createdAt: _evening,
        stockMovementId: 'sale-movement',
      ),
    ]);
    final inventory = _Inventory(
      movements: [
        _movement('morning-movement', _morning),
        _movement('evening-movement', _evening),
      ],
      balances: const {'inactive-wheat': 2},
    );
    final beforeCatalog = List<ProductCatalogReadModel>.of(catalog.items);

    final report = await _repository(
      catalog: catalog,
      purchases: purchases,
      sales: sales,
      inventory: inventory,
    ).dailyActivityReport(selectedDate: _selectedDate);

    expect(catalog.includeInactiveValues, [true]);
    expect(report.start, _start);
    expect(report.end, DateTime(2026, 7, 31));
    expect(report.totalPurchasedKg, 5);
    expect(report.totalPurchaseAmountQirsh, 3500);
    expect(report.totalSoldKg, 3);
    expect(report.totalSalesAmountQirsh, 60000);
    expect(report.estimatedSalesCostQirsh, 37041);
    expect(report.estimatedGrossProfitQirsh, 22959);
    expect(report.estimatedStockValueQirsh, 24694);
    expect(report.hasCompleteSalesCost, isTrue);
    expect(report.hasCompleteStockValuation, isTrue);
    expect(report.stockBalances.single.productId, 'inactive-wheat');
    expect(report.stockBalances.single.productName, 'Inactive wheat');
    expect(report.stockBalances.single.quantityKg, 2);
    expect(
      report.recentMovements.map((movement) => movement.id),
      ['evening-movement', 'morning-movement'],
    );
    expect(catalog.items, beforeCatalog);
    expect(purchases.writeCalls, 0);
    expect(sales.writeCalls, 0);
    expect(inventory.writeCalls, 0);
  });

  test('nullable reference cost remains missing rather than becoming zero',
      () async {
    final catalog = _Catalog([
      _product(
        'uncosted',
        'Uncosted grain',
        referenceCost: null,
      ),
    ]);
    final report = await _repository(
      catalog: catalog,
      sales: _Sales([
        SaleRecord(
          id: 'sale-null-cost',
          productId: 'uncosted',
          quantityKg: 4,
          salePriceQirshPerKg: 500,
          totalQirsh: 2000,
          createdByUserId: 'phase-106k',
          createdAt: _morning,
          stockMovementId: 'sale-null-cost-movement',
        ),
      ]),
      inventory: _Inventory(
        movements: const [],
        balances: const {'uncosted': 7},
      ),
    ).dailyActivityReport(selectedDate: _selectedDate);

    expect(report.estimatedSalesCostQirsh, isNull);
    expect(report.estimatedGrossProfitQirsh, isNull);
    expect(report.estimatedStockValueQirsh, isNull);
    expect(report.hasCompleteSalesCost, isFalse);
    expect(report.hasCompleteStockValuation, isFalse);
    expect(report.missingSalesCostProductNames, ['Uncosted grain']);
    expect(report.missingStockCostProductNames, ['Uncosted grain']);
  });

  test('each report call performs a fresh catalog read without cache',
      () async {
    final catalog = _Catalog([_product('first', 'First', referenceCost: 101)]);
    final inventory = _Inventory(
      movements: const [],
      balances: const {'first': 1, 'second': 2},
    );
    final repository = _repository(catalog: catalog, inventory: inventory);

    final first =
        await repository.dailyActivityReport(selectedDate: _selectedDate);
    catalog.items = [_product('second', 'Second', referenceCost: 303)];
    final second =
        await repository.dailyActivityReport(selectedDate: _selectedDate);

    expect(first.stockBalances.single.productId, 'first');
    expect(second.stockBalances.single.productId, 'second');
    expect(second.estimatedStockValueQirsh, 606);
    expect(catalog.readCount, 2);
    expect(catalog.includeInactiveValues, [true, true]);
  });

  test('catalog error propagates unchanged without fallback or retry',
      () async {
    final error = StateError('phase-106k-catalog-failure');
    final catalog = _Catalog(const [], error: error);
    final purchases = _Purchases(const []);
    final sales = _Sales(const []);
    final inventory = _Inventory(movements: const [], balances: const {});

    await expectLater(
      _repository(
        catalog: catalog,
        purchases: purchases,
        sales: sales,
        inventory: inventory,
      ).dailyActivityReport(selectedDate: _selectedDate),
      throwsA(same(error)),
    );

    expect(catalog.readCount, 1);
    expect(purchases.readCount, 0);
    expect(sales.readCount, 0);
    expect(inventory.readCount, 0);
  });
}

LocalReportRepository _repository({
  required _Catalog catalog,
  _Purchases? purchases,
  _Sales? sales,
  _Inventory? inventory,
}) {
  return LocalReportRepository(
    purchaseRepository: purchases ?? _Purchases(const []),
    saleRepository: sales ?? _Sales(const []),
    inventoryRepository:
        inventory ?? _Inventory(movements: const [], balances: const {}),
    productCatalogReadRepository: catalog,
  );
}

ProductCatalogReadModel _product(
  String id,
  String name, {
  bool isActive = true,
  required int? referenceCost,
}) {
  return ProductCatalogReadModel(
    id: id,
    name: name,
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: referenceCost,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
  );
}

StockMovement _movement(String id, DateTime createdAt) {
  return StockMovement(
    id: id,
    productId: 'inactive-wheat',
    movementType: StockMovementType.manualIncrease,
    quantityKg: 1,
    createdByUserId: 'phase-106k',
    createdAt: createdAt,
  );
}

final class _Catalog implements ProductCatalogReadRepository {
  _Catalog(this.items, {this.error});

  List<ProductCatalogReadModel> items;
  final Object? error;
  int readCount = 0;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCount++;
    includeInactiveValues.add(includeInactive);
    final failure = error;
    if (failure != null) throw failure;
    return List<ProductCatalogReadModel>.unmodifiable(items);
  }
}

final class _Purchases implements PurchaseRepository {
  _Purchases(this.items);

  final List<PurchaseIntake> items;
  int readCount = 0;
  int writeCalls = 0;

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    readCount++;
    return List<PurchaseIntake>.unmodifiable(items);
  }

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106K fake is read-only.');
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106K fake is read-only.');
  }
}

final class _Sales implements SaleRepository {
  _Sales(this.items);

  final List<SaleRecord> items;
  int readCount = 0;
  int writeCalls = 0;

  @override
  Future<List<SaleRecord>> listSales() async {
    readCount++;
    return List<SaleRecord>.unmodifiable(items);
  }

  @override
  Future<SaleRecord> createSale(SaleDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106K fake is read-only.');
  }

  @override
  Future<SaleRecord> cancelSale({
    required String saleId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106K fake is read-only.');
  }
}

final class _Inventory implements InventoryRepository {
  _Inventory({required this.movements, required this.balances});

  final List<StockMovement> movements;
  final Map<String, int> balances;
  int readCount = 0;
  int writeCalls = 0;

  @override
  Future<List<StockMovement>> listAllMovements() async {
    readCount++;
    return List<StockMovement>.unmodifiable(movements);
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) async {
    readCount++;
    return Map<String, int>.unmodifiable(balances);
  }

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106K fake is read-only.');
  }

  @override
  Future<int> currentStockKg(String productId) async =>
      balances[productId] ?? 0;

  @override
  Future<bool> hasOpeningBalance(String productId) async => false;

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) async {
    return movements
        .where((movement) => movement.productId == productId)
        .toList(growable: false);
  }
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final asyncMarker = source.indexOf('async {', start);
  if (asyncMarker < 0) throw StateError('Missing async body: $declaration');
  final openBrace = asyncMarker + 'async '.length;
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $declaration.');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;
