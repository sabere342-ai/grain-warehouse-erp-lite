import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
// sqlite3 is used only to create an authentic schema-v5 migration fixture.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('v5 migrates additively to v6 and preserves existing data', () async {
    final directory = await Directory.systemTemp.createTemp('phase8f-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final legacy = sqlite3.open(file.path);
    legacy.execute(
        'CREATE TABLE foundation_probes (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
    legacy.execute("INSERT INTO foundation_probes VALUES ('legacy', 'kept')");
    legacy.execute('PRAGMA user_version = 5');
    legacy.dispose();

    final database = openDatabaseFile(file);
    expect(await database.readProbe('legacy'), 'kept');
    expect(database.schemaVersion, 10);
    expect(await database.purchases.count().getSingle(), 0);
    await database.close();
  });

  test('purchase aggregate, exact totals and sequence survive reopen',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8f-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fixture = await _Fixture.file(file);
    final first = await fixture.purchases.createPurchaseIntake(
      fixture.draft(requestId: 'request-1'),
    );
    expect(first.totalAmountPiasters, 700);
    await fixture.database.close();

    fixture = await _Fixture.file(file);
    final restored = (await fixture.purchases.listPurchaseIntakes()).single;
    expect(restored.id, first.id);
    expect(restored.supplierName, 'Supplier');
    expect(restored.stockMovementId, isNot('pending'));
    final second = await fixture.purchases.createPurchaseIntake(
      fixture.draft(requestId: 'request-2'),
    );
    expect(second.id, endsWith('-2'));
    await fixture.database.close();
  });

  test('same request replays one purchase and changed payload is rejected',
      () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final first = await fixture.purchases
        .createPurchaseIntake(fixture.draft(requestId: 'same'));
    final replay = await fixture.purchases
        .createPurchaseIntake(fixture.draft(requestId: 'same'));
    expect(replay.id, first.id);
    expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
    expect(await fixture.inventory.listAllMovements(), hasLength(1));
    await expectLater(
      fixture.purchases.createPurchaseIntake(
        fixture.draft(requestId: 'same', quantityKg: 8),
      ),
      throwsStateError,
    );
  });

  test('concurrent same request creates one logical purchase', () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final attempts = await Future.wait(List.generate(
      8,
      (_) => fixture.purchases
          .createPurchaseIntake(fixture.draft(requestId: 'concurrent')),
    ));
    expect(attempts.map((value) => value.id).toSet(), hasLength(1));
    expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
    expect(await fixture.inventory.listAllMovements(), hasLength(1));
  });

  test('cancellation is durable, history-preserving and idempotent', () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final created = await fixture.purchases
        .createPurchaseIntake(fixture.draft(requestId: 'cancel'));
    final cancelled = await fixture.purchases.cancelPurchaseIntake(
      purchaseIntakeId: created.id,
      cancelledByUserId: 'owner',
      cancellationReason: 'mistake',
    );
    final replay = await fixture.purchases.cancelPurchaseIntake(
      purchaseIntakeId: created.id,
      cancelledByUserId: 'owner',
      cancellationReason: 'mistake',
    );
    expect(cancelled.isCancelled, isTrue);
    expect(replay.cancellation!.reversalMovementIds,
        cancelled.cancellation!.reversalMovementIds);
    expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
    expect(await fixture.inventory.listAllMovements(), hasLength(2));
    expect(await fixture.inventory.currentStockKg(fixture.product.id), 0);
  });

  test('wipe and restore preserve aggregate and recover sequence', () async {
    final fixture = await _Fixture.memory();
    addTearDown(fixture.database.close);
    final created = await fixture.purchases
        .createPurchaseIntake(fixture.draft(requestId: 'backup'));
    final snapshot = await fixture.purchases.listPurchaseIntakes();
    await fixture.purchases.clearForOwnerDataWipe();
    expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
    await fixture.purchases.restorePurchaseIntakesIntoEmpty(snapshot);
    expect(
        (await fixture.purchases.listPurchaseIntakes()).single.id, created.id);
    final next = await fixture.purchases
        .createPurchaseIntake(fixture.draft(requestId: 'after-restore'));
    expect(next.id, endsWith('-2'));
  });

  test('production initialization wires DriftPurchaseRepository', () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.purchaseRepository, isA<DriftPurchaseRepository>());
    await AppRepositories.close();
  });
}

class _Fixture {
  _Fixture(this.database, this.product, this.supplier, this.inventory,
      this.purchases);

  static Future<_Fixture> memory() => _build(openInMemoryTestDatabase());
  static Future<_Fixture> file(File file) => _build(openDatabaseFile(file));

  static Future<_Fixture> _build(dynamic database) async {
    final products = DriftProductRepository(database);
    final suppliers = DriftSupplierRepository(database);
    final existingProducts = await products.listProducts(includeInactive: true);
    final existingSuppliers =
        await suppliers.listSuppliers(includeInactive: true);
    final product = existingProducts.isEmpty
        ? await products.createProduct(const ProductDraft(
            name: 'Wheat', code: 'WH', unit: GrainUnit.kilogram))
        : existingProducts.single;
    final supplier = existingSuppliers.isEmpty
        ? await suppliers.createSupplier(const SupplierDraft(name: 'Supplier'))
        : existingSuppliers.single;
    final inventory =
        DriftInventoryRepository(database, productRepository: products);
    final purchases = DriftPurchaseRepository(
      database,
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
    );
    return _Fixture(database, product, supplier, inventory, purchases);
  }

  final dynamic database;
  final Product product;
  final Supplier supplier;
  final DriftInventoryRepository inventory;
  final DriftPurchaseRepository purchases;

  PurchaseIntakeDraft draft({String? requestId, int quantityKg = 7}) =>
      PurchaseIntakeDraft(
        supplierId: supplier.id,
        productId: product.id,
        quantityKg: quantityKg,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 100,
        createdByUserId: 'owner',
        operationRequestId: requestId,
      );
}
