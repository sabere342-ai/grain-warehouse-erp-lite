import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';

void main() {
  group('genuine product catalog runtime integration', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test(
        'production composition supplies the Drift adapter to document history',
        () {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
      expect(
        AppRepositories.documentHistoryRepository,
        isA<LocalDocumentHistoryRepository>(),
      );
    });

    test('an empty SQLite catalog and document store return empty history',
        () async {
      expect(await database.select(database.products).get(), isEmpty);
      expect(await AppRepositories.documentHistoryRepository.listHistory(),
          isEmpty);
    });

    test('active SQLite product resolves through document history losslessly',
        () async {
      await _seedProduct(
        database,
        id: 'prd-105e-active',
        name: 'Active wheat',
        code: 'AW-105E',
        unit: GrainUnit.ton,
        isActive: true,
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-active',
        productId: 'prd-105e-active',
        createdAt: DateTime.utc(2026, 7, 29, 10),
      );

      final stored = await database.select(database.products).get();
      final catalog = await AppRepositories.productCatalogReadRepository
          .listProductCatalog(includeInactive: false);
      final history =
          await AppRepositories.documentHistoryRepository.listHistory();

      expect(stored.single.id, 'prd-105e-active');
      expect(catalog.single.id, 'prd-105e-active');
      expect(catalog.single.id, isA<String>());
      expect(catalog.single.code, 'AW-105E');
      expect(catalog.single.unit, GrainUnit.ton);
      expect(catalog.single.isActive, isTrue);
      expect(history.single.productId, 'prd-105e-active');
      expect(history.single.productName, 'Active wheat');
    });

    test('inactive SQLite product name remains visible in historical documents',
        () async {
      await _seedProduct(
        database,
        id: 'prd-105e-inactive',
        name: 'Archived corn',
        unit: GrainUnit.kilogram,
        isActive: false,
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-inactive',
        productId: 'prd-105e-inactive',
        createdAt: DateTime.utc(2026, 7, 29, 11),
      );

      expect(
        await AppRepositories.productCatalogReadRepository
            .listProductCatalog(includeInactive: false),
        isEmpty,
      );
      final history =
          await AppRepositories.documentHistoryRepository.listHistory();

      expect(history.single.productId, 'prd-105e-inactive');
      expect(history.single.productName, 'Archived corn');
    });

    test('a direct SQLite name update is visible on the next consumer read',
        () async {
      await _seedProduct(
        database,
        id: 'prd-105e-fresh',
        name: 'Name before update',
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-fresh',
        productId: 'prd-105e-fresh',
        createdAt: DateTime.utc(2026, 7, 29, 12),
      );
      final repository = AppRepositories.documentHistoryRepository;

      expect((await repository.listHistory()).single.productName,
          'Name before update');

      await (database.update(database.products)
            ..where((row) => row.id.equals('prd-105e-fresh')))
          .write(
        const db.ProductsCompanion(
          name: Value('Name after update'),
          normalizedName: Value('name after update'),
        ),
      );

      expect((await repository.listHistory()).single.productName,
          'Name after update');
    });

    test('real mapping failure propagates and succeeds after database repair',
        () async {
      await _seedProduct(
        database,
        id: 'prd-105e-retry',
        name: 'Retry product',
        storedUnit: 'unsupported-bag',
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-retry',
        productId: 'prd-105e-retry',
        createdAt: DateTime.utc(2026, 7, 29, 13),
      );
      final repository = AppRepositories.documentHistoryRepository;

      await expectLater(
        repository.listHistory(),
        throwsA(isA<ArgumentError>()),
      );

      await (database.update(database.products)
            ..where((row) => row.id.equals('prd-105e-retry')))
          .write(
        db.ProductsCompanion(
          unit: Value(GrainUnit.kilogram.name),
        ),
      );
      final retried = await repository.listHistory();

      expect(retried, hasLength(1));
      expect(retried.single.productId, 'prd-105e-retry');
      expect(retried.single.productName, 'Retry product');
    });

    test('document timestamp ordering remains newest first', () async {
      await _seedProduct(
        database,
        id: 'prd-105e-older',
        name: 'Older product',
      );
      await _seedProduct(
        database,
        id: 'prd-105e-newer',
        name: 'Newer product',
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-older',
        productId: 'prd-105e-older',
        createdAt: DateTime.utc(2026, 7, 28, 8),
      );
      await _seedPurchase(
        database,
        id: 'pin-105e-newer',
        productId: 'prd-105e-newer',
        createdAt: DateTime.utc(2026, 7, 29, 8),
      );

      final history =
          await AppRepositories.documentHistoryRepository.listHistory();

      expect(history.map((entry) => entry.id), [
        'pin-105e-newer',
        'pin-105e-older',
      ]);
      expect(history.map((entry) => entry.productName), [
        'Newer product',
        'Older product',
      ]);
    });
  });

  test('migrated consumer has no legacy or concrete database bypass', () {
    final consumer =
        File('lib/core/documents/document_history.dart').readAsStringSync();
    final composition =
        File('lib/app/app_repositories.dart').readAsStringSync();
    final isolatedTrial =
        File('tool/run_phase102j_synthetic_trial.dart').readAsStringSync();

    expect(consumer, contains('ProductCatalogReadRepository'));
    expect(consumer, contains('listProductCatalog('));
    expect(consumer, contains('includeInactive: true'));
    expect(consumer, isNot(contains('ProductRepository')));
    expect(consumer, isNot(contains('listProducts')));
    expect(consumer, isNot(contains('DriftProductCatalogReadRepository')));
    expect(consumer, isNot(contains('FoundationDatabase')));
    expect(consumer, isNot(contains('package:drift/')));
    expect(
        composition,
        contains('_productCatalogReadRepository = '
            'DriftProductCatalogReadRepository(database)'));
    expect(
      composition,
      contains('productCatalogReadRepository: productCatalogReadRepository'),
    );
    expect(
      isolatedTrial,
      contains(
        'productCatalogReadRepository: '
        'DriftProductCatalogReadRepository(database)',
      ),
    );
  });
}

Future<void> _clearScenarioRows(db.FoundationDatabase database) async {
  await database.transaction(() async {
    await database.delete(database.inventoryMovements).go();
    await database.delete(database.purchases).go();
    await database.delete(database.sales).go();
    await database.delete(database.products).go();
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  String? code,
  GrainUnit unit = GrainUnit.kilogram,
  String? storedUnit,
  bool isActive = true,
}) async {
  final timestamp = DateTime.utc(2026, 7, 29);
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value(code),
          normalizedCode: Value(code?.toLowerCase()),
          unit: storedUnit ?? unit.name,
          isActive: isActive,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}

Future<void> _seedPurchase(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required DateTime createdAt,
}) async {
  await database.into(database.purchases).insert(
        db.PurchasesCompanion.insert(
          id: id,
          supplierId: 'sup-105e-isolated',
          productId: productId,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram.name,
          unitPricePiastersPerKg: 250,
          totalAmountPiasters: 25000,
          createdByUserId: 'owner-105e',
          createdAt: createdAt,
          stockMovementId: 'mov-$id',
          paymentMode: PurchasePaymentMode.credit.name,
        ),
      );
}
