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

const _baseline = 'fe618089672436d115ded9b02c4f1e17224cf7fb';
const _phase106bCommit = 'f7b926119ccf9cf220ff8a3e0c46b9ad5ac52650';
const _dashboardPath = 'lib/features/dashboard/dashboard_screen.dart';

void main() {
  group('Phase 106B dashboard guidance catalog migration structure', () {
    test('load uses the frozen catalog boundary exactly once', () {
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

    test('consumer has no persistence, concrete-adapter, or query bypass', () {
      final source = File(_dashboardPath).readAsStringSync();
      final body = _methodBody(
        source,
        'static Future<DashboardGuidanceState> load() async',
      );

      for (final forbidden in const [
        'AppDatabase',
        'select(products)',
        'selectOnly(products)',
        'customSelect',
        'DriftProductCatalogReadRepository(',
        'DriftProductRepository(',
        'ProductDataRepository(',
      ]) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
      for (final forbiddenImport in const [
        'drift_product_catalog_read_repository.dart',
        'foundation_database.dart',
        "package:drift/",
        'sqlite',
      ]) {
        expect(source, isNot(contains(forbiddenImport)),
            reason: forbiddenImport);
      }
    });

    test('product count does not inspect fields, filter, sort, or write', () {
      final body = _methodBody(
        File(_dashboardPath).readAsStringSync(),
        'static Future<DashboardGuidanceState> load() async',
      );

      for (final forbidden in const [
        '.id',
        '.code',
        '.unit',
        '.isActive',
        '.where(',
        '.sort(',
        'createProduct(',
        'updateProduct(',
        'deleteProduct(',
      ]) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(body, contains('productCount: products.length'));
    });

    test('the production delta is only the frozen dependency call', () {
      final diff = _git([
        'diff',
        '--unified=0',
        _baseline,
        _phase106bCommit,
        '--',
        _dashboardPath,
      ]);
      final changedLines = diff
          .split(RegExp(r'\r?\n'))
          .where((line) =>
              (line.startsWith('+') && !line.startsWith('+++')) ||
              (line.startsWith('-') && !line.startsWith('---')))
          .toList(growable: false);

      expect(changedLines, [
        '-    final products = await AppRepositories.productRepository.listProducts(',
        '-      includeInactive: true,',
        '-    );',
        '+    final products = await AppRepositories.productCatalogReadRepository',
        '+        .listProductCatalog(includeInactive: true);',
      ]);
    });

    test('no other production consumer or frozen boundary changed', () {
      expect(
        _git([
          'diff',
          _baseline,
          _phase106bCommit,
          '--name-only',
          '--',
          'lib',
        ]).trim(),
        _dashboardPath,
      );
      for (final frozenPath in const [
        'lib/app/app_repositories.dart',
        'lib/core/catalog/product_catalog_read_repository.dart',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/core/documents/document_history.dart',
      ]) {
        expect(
          _gitExitCode([
            'diff',
            '--quiet',
            _baseline,
            _phase106bCommit,
            '--',
            frozenPath,
          ]),
          0,
          reason: frozenPath,
        );
      }
    });
  });

  group('Phase 106B isolated genuine runtime behavior', () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test('production composition reaches the frozen Drift read adapter', () {
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
    });

    test('empty catalog preserves first-product guidance behavior', () async {
      final state = await DashboardGuidanceState.load();

      expect(state.productCount, 0);
      expect(state.stockMovementCount, 0);
      expect(state.saleCount, 0);
      expect(state.message, 'ابدأ بإضافة أول صنف في المخزن.');
    });

    test('active and inactive products are both counted without writes',
        () async {
      await _seedProduct(
        database,
        id: 'prd-106b-inactive',
        name: 'Inactive first',
        code: null,
        unit: GrainUnit.ton,
        isActive: false,
        createdAt: DateTime.utc(2026, 7, 30, 8),
      );
      await _seedProduct(
        database,
        id: 'prd-106b-active',
        name: 'Active second',
        code: 'ACTIVE-106B',
        unit: GrainUnit.kilogram,
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 9),
      );

      final before = await database.select(database.products).get();
      final state = await DashboardGuidanceState.load();
      final after = await database.select(database.products).get();

      expect(state.productCount, 2);
      expect(state.stockMovementCount, 0);
      expect(state.saleCount, 0);
      expect(
        state.message,
        'بعد إضافة الأصناف، سجّل رصيد افتتاحي أو وارد حبوب عند الحاجة.',
      );
      expect(after.map((row) => row.id), before.map((row) => row.id));
      expect(after, hasLength(2));
    });

    test('catalog conversion failures remain uncaught by guidance load',
        () async {
      await _seedProduct(
        database,
        id: 'prd-106b-invalid-unit',
        name: 'Invalid unit',
        code: 'INVALID-106B',
        unit: GrainUnit.kilogram,
        storedUnit: 'unsupported-unit',
        isActive: true,
        createdAt: DateTime.utc(2026, 7, 30, 10),
      );

      await expectLater(
        DashboardGuidanceState.load(),
        throwsA(isA<ArgumentError>()),
      );
    });
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

String _git(List<String> arguments) {
  final result = Process.runSync('git', arguments, runInShell: false);
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

int _gitExitCode(List<String> arguments) =>
    Process.runSync('git', arguments, runInShell: false).exitCode;
