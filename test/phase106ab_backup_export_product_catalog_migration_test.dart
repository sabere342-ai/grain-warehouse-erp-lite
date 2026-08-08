import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

const _baseline = '6c04de68e38dcc499f704970e9c00b01fbccf0f1';
const _productKeys = <String>[
  'id',
  'name',
  'code',
  'unit',
  'isActive',
  'defaultSalePricePiastersPerKg',
  'minimumSalePricePiastersPerKg',
  'referenceCostPricePiastersPerKg',
  'notes',
  'createdAt',
  'updatedAt',
];

void main() {
  group('Phase 106AB timestamp contract and Drift adapter', () {
    test('maps distinct timestamps directly at the stored precision', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final createdAt = DateTime.utc(2026, 7, 31, 22, 4, 5);
      final updatedAt = DateTime.utc(2026, 8, 1, 1, 2, 3);
      await fixture.seed(
        id: 'prd-timestamps',
        name: 'Timestamp sentinel',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final product = (await fixture.driftCatalog.listProductCatalog(
        includeInactive: true,
      ))
          .single;
      final storedRow =
          await (fixture.database.select(fixture.database.products)
                ..where((row) => row.id.equals('prd-timestamps')))
              .getSingle();

      expect(product.createdAt, storedRow.createdAt);
      expect(product.updatedAt, storedRow.updatedAt);
      expect(product.createdAt, isNot(product.updatedAt));
      expect(product.createdAt.second, 5);
      expect(product.updatedAt.second, 3);
      expect(product.createdAt.isUtc, storedRow.createdAt.isUtc);
      expect(product.updatedAt.isUtc, storedRow.updatedAt.isUtc);
    });
  });

  group('Phase 106AB backup export migration', () {
    test('real SQLite path preserves the complete legacy product payload',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final early = DateTime.utc(2026, 7, 30, 8, 15, 10);
      final tie = DateTime.utc(2026, 7, 30, 9, 16, 11);
      await fixture.seed(
        id: 'prd-early',
        name: 'Inactive nulls',
        isActive: false,
        createdAt: early,
        updatedAt: early.add(const Duration(seconds: 3)),
      );
      await fixture.seed(
        id: 'prd-tie-a',
        name: 'Active prices',
        code: '',
        notes: '  ',
        isActive: true,
        referenceCost: 2375,
        defaultSalePrice: 2750,
        minimumSalePrice: 2500,
        createdAt: tie,
        updatedAt: tie.add(const Duration(seconds: 4)),
      );
      await fixture.seed(
        id: 'prd-tie-z',
        name: 'Inactive whitespace',
        code: '  CODE  ',
        notes: '  verbatim note  ',
        isActive: false,
        referenceCost: 1,
        defaultSalePrice: 2,
        minimumSalePrice: 3,
        createdAt: tie,
        updatedAt: tie.add(const Duration(seconds: 5)),
      );
      final before = await fixture.productSnapshot();
      final runtimeService = fixture.service(fixture.driftCatalog);
      final legacyReferenceService = fixture.service(
        ProductCatalogReadRepositoryTestAdapter(
          DriftProductRepository(fixture.database),
        ),
      );

      final runtime = await runtimeService.createBackup();
      final legacyReference = await legacyReferenceService.createBackup();
      final decoded = jsonDecode(runtime.jsonText) as Map<String, Object?>;
      final data = decoded['data']! as Map<String, Object?>;
      final products =
          (data['products']! as List<Object?>).cast<Map<String, Object?>>();

      expect(runtime.jsonText, legacyReference.jsonText);
      expect(runtime.checksum, legacyReference.checksum);
      expect(runtime.backupVersion, 8);
      expect(products.map((product) => product['id']),
          ['prd-early', 'prd-tie-a', 'prd-tie-z']);
      expect(
          products.map((product) => product['isActive']), [false, true, false]);
      expect(products.every((product) => product.keys.length == 11), isTrue);
      expect(
          products.every((product) => _listEquals(
                product.keys.toList(growable: false),
                _productKeys,
              )),
          isTrue);
      expect(products.first['code'], isNull);
      expect(products.first['notes'], isNull);
      expect(products.first['defaultSalePricePiastersPerKg'], isNull);
      expect(products[1]['code'], '');
      expect(products[1]['notes'], '  ');
      expect(products[1]['referenceCostPricePiastersPerKg'], 2375);
      expect(products[1]['defaultSalePricePiastersPerKg'], 2750);
      expect(products[1]['minimumSalePricePiastersPerKg'], 2500);
      expect(products[2]['code'], '  CODE  ');
      expect(products[2]['notes'], '  verbatim note  ');
      expect(products.first['createdAt'], early.toIso8601String());
      expect(products.first['updatedAt'],
          early.add(const Duration(seconds: 3)).toIso8601String());
      expect(products.first['createdAt'], isNot(products.first['updatedAt']));
      expect(decoded['checksum'], runtime.checksum);
      expect(_checksumWithoutEnvelope(decoded), runtime.checksum);
      expect(await fixture.productSnapshot(), before);
    });

    test('empty real catalog exports an empty complete backup', () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);

      final result = await fixture.service(fixture.driftCatalog).createBackup();
      final decoded = jsonDecode(result.jsonText) as Map<String, Object?>;
      final data = decoded['data']! as Map<String, Object?>;

      expect(data['products'], isEmpty);
      expect(result.counts.products, 0);
      expect(_checksumWithoutEnvelope(decoded), result.checksum);
      expect(await fixture.productSnapshot(), isEmpty);
    });

    test('catalog failure propagates and cannot produce an incomplete backup',
        () async {
      final fixture = _Fixture.open();
      addTearDown(fixture.close);
      final catalog = _ThrowingCatalog();

      await expectLater(
        fixture.service(catalog).createBackup(),
        throwsA(isA<StateError>()),
      );
      expect(catalog.includeInactiveValues, [true]);
    });
  });

  test('Phase 106AB source and scope freeze guard', () {
    final contract = _compact(File(
      'lib/core/catalog/product_catalog_read_repository.dart',
    ).readAsStringSync());
    final adapter = _compact(File(
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
    ).readAsStringSync());
    final backup = _compact(
      File('lib/core/backup/backup_export.dart').readAsStringSync(),
    );

    expect(contract, contains('requiredthis.createdAt'));
    expect(contract, contains('requiredthis.updatedAt'));
    expect(RegExp(r'finalDateTime(createdAt|updatedAt);').allMatches(contract),
        hasLength(2));
    expect(adapter, contains('createdAt:row.read(products.createdAt)!'));
    expect(adapter, contains('updatedAt:row.read(products.updatedAt)!'));
    expect(adapter, isNot(contains('DateTime.now')));
    expect(adapter, isNot(contains('toUtc()')));
    expect(adapter, isNot(contains('toLocal()')));
    expect(
        backup,
        contains(
          '_productCatalogReadRepository.listProductCatalog(includeInactive:true,)',
        ));
    expect(backup, isNot(contains('_productRepository')));
    expect(backup, isNot(contains('listProducts(')));
    expect(
        RegExp(r"'([^']+)':product\.").allMatches(
          backup.substring(
            backup.indexOf('Map<String,Object?>_productToJson'),
            backup.indexOf('Map<String,Object?>_movementToJson'),
          ),
        ),
        hasLength(11));

    final libSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(RegExp(r'\.listProducts\(').allMatches(libSource), hasLength(7));
    expect(
        RegExp(r'\.listProductCatalog\(').allMatches(libSource), hasLength(19));

    final changed = (Process.runSync(
      'git',
      ['diff', '--name-only', _baseline, '--', 'lib'],
      runInShell: true,
    ).stdout as String)
        .split(RegExp(r'\r?\n'))
        .where((path) => path.isNotEmpty)
        .toSet();
    expect(
      changed,
      {
        'lib/app/app_repositories.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/backup/backup_restore_service.dart',
        'lib/core/backup/business_data_wipe_service.dart',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/core/catalog/product_catalog_read_repository.dart',
        'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
        'lib/core/inventory/drift_inventory_repository.dart',
        'lib/core/inventory_valuation/profitability_activation_service.dart',
        'lib/core/purchases/drift_purchase_repository.dart',
      },
    );
    expect(
        changed.any((path) => path.contains('foundation_database')), isFalse);
    expect(changed.any((path) => path.endsWith('.g.dart')), isFalse);
  });
}

final class _Fixture {
  _Fixture._(this.database, this.driftCatalog);

  factory _Fixture.open() {
    final database = openInMemoryTestDatabase();
    return _Fixture._(database, DriftProductCatalogReadRepository(database));
  }

  final db.FoundationDatabase database;
  final DriftProductCatalogReadRepository driftCatalog;

  Future<void> seed({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? code,
    String? notes,
    bool isActive = true,
    int? referenceCost,
    int? defaultSalePrice,
    int? minimumSalePrice,
  }) async {
    await database.into(database.products).insert(
          db.ProductsCompanion.insert(
            id: id,
            name: name,
            normalizedName: '$name-$id'.toLowerCase(),
            code: Value(code),
            normalizedCode: Value(code == null ? null : '$code-$id'),
            unit: GrainUnit.kilogram.name,
            isActive: isActive,
            defaultSalePricePiastersPerKg: Value(defaultSalePrice),
            minimumSalePricePiastersPerKg: Value(minimumSalePrice),
            referenceCostPricePiastersPerKg: Value(referenceCost),
            notes: Value(notes),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
  }

  BackupExportService service(ProductCatalogReadRepository catalog) {
    final products = LocalProductRepository();
    final suppliers = LocalSupplierRepository();
    final inventory = LocalInventoryRepository(productRepository: products);
    final valuation = LocalInventoryValuationRepository();
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
    );
    final sales = LocalSaleRepository(
      productRepository: products,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
    );
    final history = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productCatalogReadRepository: const _StaticCatalog(),
      inventoryRepository: inventory,
    );
    return BackupExportService(
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: history,
      inventoryValuationRepository: valuation,
      now: () => DateTime.utc(2026, 8, 1, 12, 30),
    );
  }

  Future<List<Object>> productSnapshot() async {
    final rows = await (database.select(database.products)
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    return rows
        .map<Object>((row) => (
              row.id,
              row.name,
              row.code,
              row.isActive,
              row.defaultSalePricePiastersPerKg,
              row.minimumSalePricePiastersPerKg,
              row.referenceCostPricePiastersPerKg,
              row.notes,
              row.createdAt,
              row.updatedAt,
            ))
        .toList(growable: false);
  }

  Future<void> close() => database.close();
}

final class _StaticCatalog implements ProductCatalogReadRepository {
  const _StaticCatalog();

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      const [];
}

final class _ThrowingCatalog implements ProductCatalogReadRepository {
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    includeInactiveValues.add(includeInactive);
    throw StateError('catalog read failed');
  }
}

String _checksumWithoutEnvelope(Map<String, Object?> decoded) {
  final body = <String, Object?>{
    for (final entry in decoded.entries)
      if (entry.key != 'checksum' && entry.key != 'checksumNote')
        entry.key: entry.value,
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(body);
  const modulus = 65521;
  var a = 1;
  var b = 0;
  for (final byte in utf8.encode(encoded)) {
    a = (a + byte) % modulus;
    b = (b + a) % modulus;
  }
  return ((b << 16) | a).toRadixString(16).padLeft(8, '0');
}

bool _listEquals(List<Object?> left, List<Object?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
