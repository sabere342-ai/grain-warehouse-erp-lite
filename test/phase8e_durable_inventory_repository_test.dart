import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';

const _productDraft =
    ProductDraft(name: 'Wheat', code: 'WH', unit: GrainUnit.kilogram);

void main() {
  test('movements, balances, ordering and sequence survive reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase8e-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var products = DriftProductRepository(database);
    final product = await products.createProduct(_productDraft);
    var inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    final first = await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 100,
      createdByUserId: 'owner',
      note: ' opening ',
    ));
    await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.sale,
      quantityKg: 30,
      createdByUserId: 'owner',
      originalDocumentId: 'sale-1',
    ));
    await database.close();

    database = openDatabaseFile(file);
    products = DriftProductRepository(database);
    inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    expect(await inventory.currentStockKg(product.id), 70);
    expect((await inventory.listAllMovements()).map((value) => value.id).first,
        first.id);
    final third = await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.manualIncrease,
      quantityKg: 1,
      createdByUserId: 'owner',
    ));
    expect(third.id, endsWith('-3'));
    await database.close();
  });

  test('opening balance, product and negative-stock invariants are preserved',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final products = DriftProductRepository(database);
    final product = await products.createProduct(_productDraft);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 10,
      createdByUserId: 'owner',
    ));
    await expectLater(
      inventory.createMovement(StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 1,
        createdByUserId: 'owner',
      )),
      throwsStateError,
    );
    await expectLater(
      inventory.createMovement(StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.sale,
        quantityKg: 11,
        createdByUserId: 'owner',
      )),
      throwsStateError,
    );
    await expectLater(inventory.currentStockKg('missing'), throwsStateError);
    expect(await inventory.currentStockKg(product.id), 10);
  });

  test('concurrent creates allocate unique durable ids and exact balance',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final products = DriftProductRepository(database);
    final product = await products.createProduct(_productDraft);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    final movements = await Future.wait(List.generate(
      20,
      (_) => inventory.createMovement(StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.manualIncrease,
        quantityKg: 2,
        createdByUserId: 'owner',
      )),
    ));
    expect(movements.map((value) => value.id).toSet(), hasLength(20));
    expect(await inventory.currentStockKg(product.id), 40);
  });

  test('failed repository transaction restores movements and sequence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final products = DriftProductRepository(database);
    final product = await products.createProduct(_productDraft);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    await expectLater(
      RepositoryTransaction.execute([inventory.createTransactionSnapshot()],
          () async {
        await inventory.createMovement(StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.manualIncrease,
          quantityKg: 5,
          createdByUserId: 'owner',
        ));
        throw const FormatException('injected');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(await inventory.listAllMovements(), isEmpty);
    final created = await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.manualIncrease,
      quantityKg: 1,
      createdByUserId: 'owner',
    ));
    expect(created.id, endsWith('-1'));
  });

  test('wipe and restore preserve ids, fields, balance and next sequence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final products = DriftProductRepository(database);
    final product = await products.createProduct(_productDraft);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    );
    final original = await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.purchaseIntake,
      quantityKg: 9,
      createdByUserId: 'owner',
      note: 'purchase',
      originalDocumentId: 'purchase-1',
    ));
    final snapshot = await inventory.listAllMovements();
    await inventory.clearForOwnerDataWipe();
    await inventory.restoreMovementsIntoEmpty(snapshot);
    expect(await inventory.listAllMovements(), hasLength(1));
    expect((await inventory.listAllMovements()).single.originalDocumentId,
        'purchase-1');
    expect(await inventory.currentStockKg(product.id), 9);
    final next = await inventory.createMovement(StockMovementDraft(
      productId: product.id,
      movementType: StockMovementType.manualIncrease,
      quantityKg: 1,
      createdByUserId: 'owner',
    ));
    expect(next.id, isNot(original.id));
    expect(next.id, endsWith('-2'));
  });

  test('production initialization wires one Drift inventory instance',
      () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(
        AppRepositories.inventoryRepository, isA<DriftInventoryRepository>());
    await AppRepositories.close();
  });
}
