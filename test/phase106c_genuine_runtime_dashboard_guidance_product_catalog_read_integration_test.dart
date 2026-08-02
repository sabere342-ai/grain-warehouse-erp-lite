import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';

const _dashboardPath = 'lib/features/dashboard/dashboard_screen.dart';

void main() {
  group('Phase 106C genuine dashboard guidance runtime integration', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition reaches the isolated Drift catalog adapter',
        () {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
    });

    test('empty SQLite products table produces a zero product count', () async {
      expect(await database.select(database.products).get(), isEmpty);

      final state = await DashboardGuidanceState.load();

      expect(state.productCount, 0);
      expect(state.stockMovementCount, 0);
      expect(state.saleCount, 0);
      expect(await database.select(database.products).get(), isEmpty);
    });

    test('active and inactive SQLite rows are all counted without writes',
        () async {
      await _seedProduct(
        database,
        id: 'prd-106c-active-a',
        name: 'Active wheat',
        code: 'ACTIVE-A',
        unit: GrainUnit.ton,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 8),
      );
      await _seedProduct(
        database,
        id: 'prd-106c-inactive',
        name: 'Inactive corn',
        code: null,
        unit: GrainUnit.kilogram,
        isActive: false,
        createdAt: DateTime.utc(2026, 7, 30, 9),
      );
      await _seedProduct(
        database,
        id: 'prd-106c-active-b',
        name: 'Active barley',
        code: 'ACTIVE-B',
        unit: GrainUnit.kilogram,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 10),
      );
      final before = await _productSnapshot(database);

      final state = await DashboardGuidanceState.load();

      expect(state.productCount, before.length);
      expect(state.productCount, 3);
      expect(await _productSnapshot(database), before);
    });

    test('a second load reflects a newly inserted SQLite product', () async {
      await _seedProduct(
        database,
        id: 'prd-106c-first',
        name: 'First product',
        code: 'FIRST',
        unit: GrainUnit.kilogram,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 11),
      );
      await _seedProduct(
        database,
        id: 'prd-106c-second',
        name: 'Second product',
        code: null,
        unit: GrainUnit.ton,
        isActive: false,
        createdAt: DateTime.utc(2026, 7, 30, 12),
      );

      expect((await DashboardGuidanceState.load()).productCount, 2);

      await _seedProduct(
        database,
        id: 'prd-106c-third',
        name: 'Third product',
        code: 'THIRD',
        unit: GrainUnit.kilogram,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 13),
      );

      expect((await DashboardGuidanceState.load()).productCount, 3);
    });

    test('load succeeds through the extended catalog projection', () async {
      await _seedProduct(
        database,
        id: 'prd-106c-legacy-sentinel',
        name: 'Catalog projection sentinel',
        code: 'SENTINEL',
        unit: GrainUnit.kilogram,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 14),
      );
      final state = await DashboardGuidanceState.load();

      expect(state.productCount, 1);
    });

    test('real catalog conversion errors propagate without fallback', () async {
      await _seedProduct(
        database,
        id: 'prd-106c-invalid-unit',
        name: 'Invalid unit',
        code: 'INVALID-UNIT',
        unit: GrainUnit.kilogram,
        storedUnit: 'unsupported-unit',
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 15),
      );

      await expectLater(
        DashboardGuidanceState.load(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('consumer source retains the catalog path and has no legacy bypass', () {
    final source = File(_dashboardPath).readAsStringSync();
    final body = _methodBody(
      source,
      'static Future<DashboardGuidanceState> load() async',
    );

    expect(
      _occurrences(body, 'AppRepositories.productCatalogReadRepository'),
      1,
    );
    expect(_occurrences(body, '.listProductCatalog('), 1);
    expect(body, contains('includeInactive: true'));
    expect(body, contains('productCount: products.length'));
    expect(body, isNot(contains('AppRepositories.productRepository')));
    expect(body, isNot(contains('.listProducts(')));
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
  required String? code,
  required GrainUnit unit,
  required bool isActive,
  required DateTime createdAt,
  String? storedUnit,
}) async {
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value(code),
          normalizedCode: Value(code?.toLowerCase()),
          unit: storedUnit ?? unit.name,
          isActive: isActive,
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

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('Missing method: $signature');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $signature.');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;
