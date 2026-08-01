import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

void main() {
  group('Phase 106U ProductCatalogReadModel expansion', () {
    test('model carries the two new sale price fields with real values', () {
      const model = ProductCatalogReadModel(
        id: 'prd-106u-model',
        name: 'قمح',
        code: 'WHEAT',
        unit: GrainUnit.kilogram,
        isActive: true,
        referenceCostPricePiastersPerKg: 2800,
        defaultSalePricePiastersPerKg: 3000,
        minimumSalePricePiastersPerKg: 2500,
      );

      expect(model.id, 'prd-106u-model');
      expect(model.name, 'قمح');
      expect(model.code, 'WHEAT');
      expect(model.unit, GrainUnit.kilogram);
      expect(model.isActive, isTrue);
      expect(model.referenceCostPricePiastersPerKg, 2800);
      expect(model.defaultSalePricePiastersPerKg, 3000);
      expect(model.minimumSalePricePiastersPerKg, 2500);
    });

    test('all optional price fields remain nullable', () {
      const model = ProductCatalogReadModel(
        id: 'prd-106u-null',
        name: 'شعير',
        code: null,
        unit: GrainUnit.ton,
        isActive: false,
        referenceCostPricePiastersPerKg: null,
        defaultSalePricePiastersPerKg: null,
        minimumSalePricePiastersPerKg: null,
      );

      expect(model.code, isNull);
      expect(model.referenceCostPricePiastersPerKg, isNull);
      expect(model.defaultSalePricePiastersPerKg, isNull);
      expect(model.minimumSalePricePiastersPerKg, isNull);
    });
  });

  group('Phase 106U Drift catalog adapter price mapping', () {
    test('maps default and minimum sale price columns from SQLite rows',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 8);
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-priced',
        name: 'Priced wheat',
        isActive: true,
        referenceCost: 2750,
        defaultSalePrice: 3100,
        minimumSalePrice: 2600,
        createdAt: time,
      );

      final catalog = await fixture.repository.listProductCatalog(
        includeInactive: true,
      );

      final product = catalog.single;
      expect(product.id, 'prd-106u-priced');
      expect(product.referenceCostPricePiastersPerKg, 2750);
      expect(product.defaultSalePricePiastersPerKg, 3100);
      expect(product.minimumSalePricePiastersPerKg, 2600);
    });

    test('preserves null prices without defaulting or rounding', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 9);
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-null-prices',
        name: 'Unpriced barley',
        isActive: true,
        referenceCost: null,
        defaultSalePrice: null,
        minimumSalePrice: null,
        createdAt: time,
      );

      final catalog = await fixture.repository.listProductCatalog(
        includeInactive: true,
      );

      expect(catalog.single.referenceCostPricePiastersPerKg, isNull);
      expect(catalog.single.defaultSalePricePiastersPerKg, isNull);
      expect(catalog.single.minimumSalePricePiastersPerKg, isNull);
    });

    test('orders by createdAt ascending then id ascending', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 10);
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-order-b',
        name: 'B',
        isActive: true,
        referenceCost: null,
        createdAt: time.add(const Duration(hours: 1)),
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-order-a',
        name: 'A',
        isActive: true,
        referenceCost: null,
        createdAt: time,
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-order-c',
        name: 'C',
        isActive: true,
        referenceCost: null,
        createdAt: time.add(const Duration(hours: 1)),
      );

      final catalog = await fixture.repository.listProductCatalog(
        includeInactive: true,
      );

      expect(
        catalog.map((product) => product.id).toList(),
        ['prd-106u-order-a', 'prd-106u-order-b', 'prd-106u-order-c'],
      );
    });

    test('includeInactive filters to active rows when false', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 11);
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-filter-active',
        name: 'Active',
        isActive: true,
        referenceCost: null,
        createdAt: time,
      );
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-filter-inactive',
        name: 'Inactive',
        isActive: false,
        referenceCost: null,
        createdAt: time.add(const Duration(minutes: 1)),
      );

      final activeOnly = await fixture.repository.listProductCatalog(
        includeInactive: false,
      );
      final withInactive = await fixture.repository.listProductCatalog(
        includeInactive: true,
      );

      expect(activeOnly.map((product) => product.id).toList(),
          ['prd-106u-filter-active']);
      expect(withInactive.map((product) => product.id).toList(),
          ['prd-106u-filter-active', 'prd-106u-filter-inactive']);
    });

    test('empty SQLite catalog returns an empty immutable list', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);

      final catalog = await fixture.repository.listProductCatalog(
        includeInactive: true,
      );

      expect(catalog, isEmpty);
      expect(
        () => catalog.add(
          const ProductCatalogReadModel(
            id: 'synthetic',
            name: 'Synthetic',
            code: null,
            unit: GrainUnit.kilogram,
            isActive: true,
            referenceCostPricePiastersPerKg: null,
            defaultSalePricePiastersPerKg: null,
            minimumSalePricePiastersPerKg: null,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('listing is read-only and never writes to the database', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final time = DateTime.utc(2026, 7, 30, 12);
      await _seedProduct(
        fixture.database,
        id: 'prd-106u-readonly',
        name: 'Read only',
        isActive: true,
        referenceCost: 12345,
        defaultSalePrice: 13000,
        minimumSalePrice: 11000,
        createdAt: time,
      );
      final before = await _productSnapshot(fixture.database);

      await fixture.repository.listProductCatalog(includeInactive: true);
      await fixture.repository.listProductCatalog(includeInactive: false);

      expect(await _productSnapshot(fixture.database), before);
    });
  });

  group('Phase 106U production composition', () {
    test('reaches the real Drift adapter and maps both price columns',
        () async {
      final database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
      addTearDown(AppRepositories.close);
      final time = DateTime.utc(2026, 7, 30, 13);
      await _seedProduct(
        database,
        id: 'prd-106u-production',
        name: 'Production sentinel',
        isActive: true,
        referenceCost: 2850,
        defaultSalePrice: 3200,
        minimumSalePrice: 2700,
        createdAt: time,
      );

      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
      final catalog = await AppRepositories.productCatalogReadRepository
          .listProductCatalog(includeInactive: true);
      expect(catalog.single.id, 'prd-106u-production');
      expect(catalog.single.referenceCostPricePiastersPerKg, 2850);
      expect(catalog.single.defaultSalePricePiastersPerKg, 3200);
      expect(catalog.single.minimumSalePricePiastersPerKg, 2700);
    });
  });

  test('adapter selects both price columns with no fallback or retry', () {
    final source = _compact(File(_adapterPath).readAsStringSync());

    expect(source, contains('products.defaultSalePricePiastersPerKg'));
    expect(source, contains('products.minimumSalePricePiastersPerKg'));
    expect(source, contains('defaultSalePricePiastersPerKg:'));
    expect(source, contains('minimumSalePricePiastersPerKg:'));
    expect(source, isNot(contains('listProducts(')));
    expect(source, isNot(contains('catch (')));
    expect(source, isNot(contains('retry')));
    expect(source, isNot(contains('try{')));
    expect(source, contains('OrderingTerm.asc(products.createdAt)'));
    expect(source, contains('OrderingTerm.asc(products.id)'));
  });
}

final class _Fixture {
  _Fixture._(this.database, this.repository);

  factory _Fixture.open() {
    final database = openInMemoryTestDatabase();
    return _Fixture._(
      database,
      DriftProductCatalogReadRepository(database),
    );
  }

  final db.FoundationDatabase database;
  final DriftProductCatalogReadRepository repository;

  Future<void> close() => database.close();
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
          code: const Value(null),
          normalizedCode: const Value(null),
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

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
