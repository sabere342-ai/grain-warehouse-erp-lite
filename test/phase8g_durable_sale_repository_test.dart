import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
// sqlite3 is used only to turn a generated v7 database into an authentic
// populated v6 migration fixture by removing the v7-only table.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('populated v6 migrates additively to v7', () async {
    final directory = await Directory.systemTemp.createTemp('phase8g-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = await _Fixture.file(file);
    await seeded.database.writeProbe('legacy', 'kept');
    await seeded.database.into(seeded.database.purchases).insert(
          db.PurchasesCompanion.insert(
            id: 'pur-seeded',
            supplierId: 'sup-seeded',
            productId: seeded.product.id,
            quantityKg: 1,
            entryUnit: GrainUnit.kilogram.name,
            unitPricePiastersPerKg: 100,
            totalAmountPiasters: 100,
            createdByUserId: 'owner',
            createdAt: DateTime(2026),
            stockMovementId: 'mov-seeded',
            paymentMode: PurchasePaymentMode.credit.name,
          ),
        );
    await seeded.database.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE sales');
    legacy.execute('PRAGMA user_version = 6');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    expect(upgraded.schemaVersion, 15);
    expect(await upgraded.readProbe('legacy'), 'kept');
    expect(await upgraded.purchases.count().getSingle(), 1);
    expect(await upgraded.sales.count().getSingle(), 0);
    await upgraded.close();
  });

  test('sale fields, items, allocations and order survive reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase8g-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fixture = await _Fixture.file(file);
    final first = await fixture.sales.createSale(fixture.draft('request-1'));
    final second = await fixture.sales.createSale(fixture.draft('request-2'));
    await fixture.database.close();

    fixture = await _Fixture.file(file);
    final restored = await fixture.sales.listSales();
    expect(restored.map((sale) => sale.id), [first.id, second.id]);
    expect(restored.first.items.single.lineTotalQirsh, 700);
    expect(restored.first.customerId, 'customer-1');
    expect(restored.first.createdByUserName, 'Owner');
    expect(restored.first.paymentAllocations.single.amountQirsh, 700);
    expect(restored.first.paymentMethod, PaymentMethod.cash);
    await fixture.database.close();
  });

  test('request replay state survives restart and changed request is rejected',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8g-replay-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fixture = await _Fixture.file(file);
    await fixture.sales.createSale(fixture.draft('same'));
    await fixture.database.close();
    fixture = await _Fixture.file(file);
    await expectLater(
      fixture.sales.createSale(fixture.draft('same')),
      throwsStateError,
    );
    expect(await fixture.sales.listSales(), hasLength(1));
    await fixture.database.close();
  });

  test('concurrent same request creates one logical sale', () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final results = await Future.wait(List.generate(8, (_) async {
      try {
        return await fixture.sales.createSale(fixture.draft('concurrent'));
      } on StateError {
        return null;
      }
    }));
    expect(results.whereType<SaleRecord>(), hasLength(1));
    expect(await fixture.sales.listSales(), hasLength(1));
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 93);
  });

  test('cancellation is durable, historical and idempotent', () async {
    final directory = await Directory.systemTemp.createTemp('phase8g-cancel-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fixture = await _Fixture.file(file);
    final created = await fixture.sales.createSale(fixture.draft('cancel'));
    final cancelled = await fixture.sales.cancelSale(
      saleId: created.id,
      cancelledByUserId: 'owner',
      cancellationReason: 'mistake',
    );
    final replay = await fixture.sales.cancelSale(
      saleId: created.id,
      cancelledByUserId: 'owner',
      cancellationReason: 'mistake',
    );
    expect(replay.cancellation!.reversalMovementIds,
        cancelled.cancellation!.reversalMovementIds);
    await fixture.database.close();
    fixture = await _Fixture.file(file);
    expect((await fixture.sales.listSales()).single.isCancelled, isTrue);
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
    await fixture.database.close();
  });

  test('wipe and restore round-trip preserves request metadata', () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final created = await fixture.sales.createSale(fixture.draft('backup'));
    final snapshot = await fixture.sales.listSales();
    await fixture.sales.clearForOwnerDataWipe();
    expect(await fixture.sales.listSales(), isEmpty);
    await fixture.sales.restoreSalesIntoEmpty(snapshot);
    final restored = (await fixture.sales.listSales()).single;
    expect(restored.id, created.id);
    expect(restored.operationRequestId, 'backup');
  });

  test('production initialization wires DriftSaleRepository', () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.saleRepository, isA<DriftSaleRepository>());
    await AppRepositories.close();
  });
}

class _Fixture {
  _Fixture(
      this.database, this.products, this.product, this.inventory, this.sales);

  static Future<_Fixture> memory() => _build(openInMemoryTestDatabase());
  static Future<_Fixture> file(File file) => _build(openDatabaseFile(file));

  static Future<_Fixture> _build(dynamic database) async {
    final products = DriftProductRepository(database);
    final existing = await products.listProducts(includeInactive: true);
    final product = existing.isEmpty
        ? await products.createProduct(const ProductDraft(
            name: 'Wheat', code: 'WH', unit: GrainUnit.kilogram))
        : existing.single;
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    if (!await inventory.hasOpeningBalance(product.id)) {
      await inventory.createMovement(StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 100,
        createdByUserId: 'owner',
      ));
    }
    final sales = DriftSaleRepository(
      database,
      productRepository: products,
      inventoryRepository: inventory,
    );
    return _Fixture(database, products, product, inventory, sales);
  }

  final dynamic database;
  final DriftProductRepository products;
  final Product product;
  final DriftInventoryRepository inventory;
  final DriftSaleRepository sales;

  SaleDraft draft(String requestId) => SaleDraft(
        productId: product.id,
        quantityKg: 7,
        salePriceQirshPerKg: 100,
        createdByUserId: 'owner',
        createdByUserName: 'Owner',
        customerId: 'customer-1',
        financialAccountId: 'cash-1',
        paymentMethod: PaymentMethod.cash,
        operationRequestId: requestId,
      );
}
