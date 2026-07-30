import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';

const _acceptanceReport =
    'docs/PHASE-105F-ACCEPT-FREEZE-FIRST-PRODUCT-CATALOG-READ-BOUNDARY-PILOT.md';
const _phase105fCommit = 'a813a70';

void main() {
  test('frozen read model types and narrow repository surface remain exact',
      () {
    const model = ProductCatalogReadModel(
      id: 'prd-105f-text-id',
      name: 'Frozen wheat',
      code: null,
      unit: GrainUnit.ton,
      isActive: false,
      referenceCostPricePiastersPerKg: null,
    );

    final String id = model.id;
    final String name = model.name;
    final String? code = model.code;
    final GrainUnit unit = model.unit;
    final bool isActive = model.isActive;
    expect([
      id,
      name,
      code,
      unit,
      isActive
    ], [
      'prd-105f-text-id',
      'Frozen wheat',
      null,
      GrainUnit.ton,
      false,
    ]);

    final source = _read(
      'lib/core/catalog/product_catalog_read_repository.dart',
    );
    final repositoryBody = _classBody(
      source,
      'abstract interface class ProductCatalogReadRepository',
    );
    expect(RegExp(r'\bFuture<').allMatches(repositoryBody), hasLength(1));
    expect(repositoryBody, contains('listProductCatalog({'));
    expect(repositoryBody, contains('required bool includeInactive'));
    for (final forbidden in const [
      'createProduct',
      'updateProduct',
      'setProductActive',
      'restoreProduct',
      'clearForOwnerDataWipe',
    ]) {
      expect(repositoryBody, isNot(contains(forbidden)));
    }
  });

  test('accepted runtime path preserves Drift fidelity and inactive names',
      () async {
    final database = openInMemoryTestDatabase();
    var initialized = false;
    addTearDown(() async {
      if (initialized) await AppRepositories.close();
    });

    await AppRepositories.initializeProduction(
      databaseFactory: () async => database,
    );
    initialized = true;

    expect(
      AppRepositories.productCatalogReadRepository,
      isA<DriftProductCatalogReadRepository>(),
    );
    expect(
      AppRepositories.documentHistoryRepository,
      isA<LocalDocumentHistoryRepository>(),
    );

    await _seedProduct(
      database,
      id: 'prd-105f-active',
      name: 'Active wheat',
      unit: GrainUnit.ton,
      isActive: true,
      createdAt: DateTime.utc(2026, 7, 29, 8),
    );
    await _seedProduct(
      database,
      id: 'prd-105f-inactive',
      name: 'Archived corn',
      code: 'ARC-105F',
      unit: GrainUnit.kilogram,
      isActive: false,
      createdAt: DateTime.utc(2026, 7, 29, 9),
    );
    await _seedPurchase(
      database,
      id: 'pin-105f-inactive',
      productId: 'prd-105f-inactive',
    );

    final activeOnly = await AppRepositories.productCatalogReadRepository
        .listProductCatalog(includeInactive: false);
    final complete = await AppRepositories.productCatalogReadRepository
        .listProductCatalog(includeInactive: true);
    final history =
        await AppRepositories.documentHistoryRepository.listHistory();

    expect(activeOnly.map((product) => product.id), ['prd-105f-active']);
    expect(complete.map((product) => product.id), [
      'prd-105f-active',
      'prd-105f-inactive',
    ]);
    expect(complete.first.id, isA<String>());
    expect(complete.first.code, isNull);
    expect(complete.first.unit, GrainUnit.ton);
    expect(complete.first.isActive, isTrue);
    expect(complete.last.code, 'ARC-105F');
    expect(complete.last.isActive, isFalse);
    expect(history.single.productId, 'prd-105f-inactive');
    expect(history.single.productName, 'Archived corn');

    await _seedProduct(
      database,
      id: 'prd-105f-invalid-unit',
      name: 'Invalid unit row',
      storedUnit: 'silent-fallback-is-forbidden',
      createdAt: DateTime.utc(2026, 7, 29, 10),
    );
    await expectLater(
      AppRepositories.productCatalogReadRepository
          .listProductCatalog(includeInactive: true),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('consumer dependency, inactive lookup, and composition stay frozen', () {
    final consumer = _read('lib/core/documents/document_history.dart');
    final composition = _read('lib/app/app_repositories.dart');
    final lookup = _methodBody(
      consumer,
      'Future<Map<String, String>> _productNamesById()',
    );

    expect(
      consumer,
      contains('required ProductCatalogReadRepository '
          'productCatalogReadRepository'),
    );
    expect(
      consumer,
      contains('final ProductCatalogReadRepository '
          '_productCatalogReadRepository;'),
    );
    expect(lookup, contains('.listProductCatalog('));
    expect(lookup, contains('includeInactive: true'));
    expect(lookup, contains('Map<String, String>'));
    expect(lookup, contains('product.id: product.name'));

    for (final forbidden in const [
      'ProductRepository',
      'listProducts',
      'DriftProductCatalogReadRepository',
      'FoundationDatabase',
      'package:drift/',
      'sqlite',
      'Widget',
      'BuildContext',
    ]) {
      expect(consumer, isNot(contains(forbidden)));
    }

    expect(
      composition,
      contains(
        '_productCatalogReadRepository = '
        'DriftProductCatalogReadRepository(database)',
      ),
    );
    expect(
      composition,
      contains('static ProductCatalogReadRepository '
          '_productCatalogReadRepository'),
    );
    expect(
      composition,
      contains('productCatalogReadRepository: productCatalogReadRepository'),
    );
  });

  test('the accepted boundary introduces no UI coupling', () {
    expect(
      Process.runSync(
        'git',
        [
          'grep',
          '-E',
          'ProductCatalogReadRepository|DriftProductCatalogReadRepository',
          _phase105fCommit,
          '--',
          'lib/features',
        ],
        runInShell: false,
      ).exitCode,
      1,
    );
  });

  test('pilot manifest and prior integration evidence remain complete', () {
    const manifest = {
      'Contract': 'lib/core/catalog/product_catalog_read_repository.dart',
      'Read model': 'lib/core/catalog/product_catalog_read_repository.dart',
      'Local Drift adapter':
          'lib/core/catalog/drift_product_catalog_read_repository.dart',
      'Migrated consumer': 'lib/core/documents/document_history.dart',
      'Runtime composition': 'lib/app/app_repositories.dart',
      'Integration proof':
          'test/phase105e_genuine_runtime_product_catalog_read_integration_test.dart',
      'Regression suite':
          'test/phase105d_product_catalog_application_read_boundary_migration_test.dart',
      'Acceptance report': _acceptanceReport,
    };

    for (final entry in manifest.entries) {
      expect(File(entry.value).existsSync(), isTrue, reason: entry.key);
    }

    final phase105e = _read(manifest['Integration proof']!);
    final databaseOpener = _read('lib/core/persistence/database_opener.dart');
    expect(phase105e, contains('openInMemoryTestDatabase()'));
    expect(phase105e, contains('AppRepositories.initializeProduction'));
    expect(phase105e, contains('DriftProductCatalogReadRepository'));
    expect(databaseOpener, contains('NativeDatabase.memory'));
  });

  test('governing report freezes the pilot without claiming legacy migration',
      () {
    final report = _read(_acceptanceReport);
    for (final statement in const [
      'Outcome A — FULL SUCCESS',
      'LocalDocumentHistoryRepository',
      'ProductCatalogReadRepository',
      'DriftProductCatalogReadRepository',
      'Drift / SQLite products table',
      'String id',
      'String name',
      'String? code',
      'GrainUnit unit',
      'bool isActive',
      'includeInactive: true',
      'Map<String, String>',
      'NativeDatabase.memory',
      'Out-of-scope legacy surfaces',
      'Phase 106A',
    ]) {
      expect(report, contains(statement));
    }
    expect(
      report,
      matches(
        RegExp(
          r'does not claim that every Product read\s+has been migrated',
        ),
      ),
    );
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required DateTime createdAt,
  String? code,
  GrainUnit unit = GrainUnit.kilogram,
  String? storedUnit,
  bool isActive = true,
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

Future<void> _seedPurchase(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
}) async {
  await database.into(database.purchases).insert(
        db.PurchasesCompanion.insert(
          id: id,
          supplierId: 'sup-105f-isolated',
          productId: productId,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram.name,
          unitPricePiastersPerKg: 250,
          totalAmountPiasters: 25000,
          createdByUserId: 'owner-105f',
          createdAt: DateTime.utc(2026, 7, 29, 11),
          stockMovementId: 'mov-$id',
          paymentMode: PurchasePaymentMode.credit.name,
        ),
      );
}

String _read(String filePath) => File(filePath).readAsStringSync();

String _classBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _balancedBody(source, start);
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('Missing method: $signature');
  return _balancedBody(source, start);
}

String _balancedBody(String source, int start) {
  final openBrace = source.indexOf('{', start);
  if (openBrace < 0) throw StateError('Missing opening brace.');
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace.');
}
