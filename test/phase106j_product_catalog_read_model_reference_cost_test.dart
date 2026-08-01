import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

void main() {
  test('contract exposes a required nullable integer reference cost', () {
    const costed = ProductCatalogReadModel(
      id: 'prd-costed',
      name: 'Costed wheat',
      code: null,
      unit: GrainUnit.kilogram,
      isActive: true,
      referenceCostPricePiastersPerKg: 2375,
      defaultSalePricePiastersPerKg: 2750,
      minimumSalePricePiastersPerKg: 2500,
    );
    const uncosted = ProductCatalogReadModel(
      id: 'prd-uncosted',
      name: 'Uncosted corn',
      code: null,
      unit: GrainUnit.ton,
      isActive: false,
      referenceCostPricePiastersPerKg: null,
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
    );

    final int? exactCost = costed.referenceCostPricePiastersPerKg;
    final int? absentCost = uncosted.referenceCostPricePiastersPerKg;
    expect(exactCost, 2375);
    expect(absentCost, isNull);
  });

  test('maps exact integer and null while preserving activity filtering',
      () async {
    final fixture = _fixture();
    await _insertProduct(
      fixture.database,
      id: 'prd-active',
      name: 'Active',
      isActive: true,
      referenceCost: 2375,
    );
    await _insertProduct(
      fixture.database,
      id: 'prd-inactive',
      name: 'Inactive',
      isActive: false,
      referenceCost: null,
    );

    final activeOnly =
        await fixture.repository.listProductCatalog(includeInactive: false);
    final complete =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(activeOnly.map((product) => product.id), ['prd-active']);
    expect(activeOnly.single.referenceCostPricePiastersPerKg, 2375);
    expect(complete.map((product) => product.id), [
      'prd-active',
      'prd-inactive',
    ]);
    expect(complete.first.referenceCostPricePiastersPerKg, 2375);
    expect(complete.last.referenceCostPricePiastersPerKg, isNull);
  });

  test('keeps createdAt ascending then id ascending ordering', () async {
    final fixture = _fixture();
    final older = DateTime.utc(2026, 7, 27);
    final tied = DateTime.utc(2026, 7, 28);
    await _insertProduct(
      fixture.database,
      id: 'prd-tied-z',
      name: 'Tie Z',
      createdAt: tied,
      referenceCost: 3003,
    );
    await _insertProduct(
      fixture.database,
      id: 'prd-older',
      name: 'Older',
      createdAt: older,
      referenceCost: 1001,
    );
    await _insertProduct(
      fixture.database,
      id: 'prd-tied-a',
      name: 'Tie A',
      createdAt: tied,
      referenceCost: 2002,
    );

    final result =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(result.map((product) => product.id), [
      'prd-older',
      'prd-tied-a',
      'prd-tied-z',
    ]);
    expect(
      result.map((product) => product.referenceCostPricePiastersPerKg),
      [1001, 2002, 3003],
    );
  });

  test('performs a fresh read and returns a changed integer unchanged',
      () async {
    final fixture = _fixture();
    await _insertProduct(
      fixture.database,
      id: 'prd-fresh',
      name: 'Fresh',
      referenceCost: 2375,
    );

    final first =
        await fixture.repository.listProductCatalog(includeInactive: true);
    await (fixture.database.update(fixture.database.products)
          ..where((product) => product.id.equals('prd-fresh')))
        .write(
      const db.ProductsCompanion(
        referenceCostPricePiastersPerKg: Value(4123),
      ),
    );
    final second =
        await fixture.repository.listProductCatalog(includeInactive: true);

    expect(first.single.referenceCostPricePiastersPerKg, 2375);
    expect(second.single.referenceCostPricePiastersPerKg, 4123);
  });

  test('passes mapping errors through and performs no writes', () async {
    final fixture = _fixture();
    await _insertProduct(
      fixture.database,
      id: 'prd-valid',
      name: 'Valid',
      referenceCost: 2375,
    );
    final before =
        await fixture.database.select(fixture.database.products).get();

    await fixture.repository.listProductCatalog(includeInactive: true);

    final after =
        await fixture.database.select(fixture.database.products).get();
    expect(after, before);

    await _insertProduct(
      fixture.database,
      id: 'prd-invalid-unit',
      name: 'Invalid unit',
      storedUnit: 'bag',
      referenceCost: null,
    );
    await expectLater(
      fixture.repository.listProductCatalog(includeInactive: true),
      throwsArgumentError,
    );
  });
}

({
  db.FoundationDatabase database,
  DriftProductCatalogReadRepository repository,
}) _fixture() {
  final database = openInMemoryTestDatabase();
  addTearDown(database.close);
  return (
    database: database,
    repository: DriftProductCatalogReadRepository(database),
  );
}

Future<void> _insertProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required int? referenceCost,
  bool isActive = true,
  DateTime? createdAt,
  String storedUnit = 'kilogram',
}) async {
  final timestamp = createdAt ?? DateTime.utc(2026, 7, 28);
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '${name}_$id'.toLowerCase(),
          unit: storedUnit,
          isActive: isActive,
          referenceCostPricePiastersPerKg: Value(referenceCost),
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}
