import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

const _baseline = '1d1b24afac39fe3e83704aa73747568c2c9b525c';
const _subject =
    'PHASE 106AF: migrate business data wipe current counts product read';
const _servicePath = 'lib/core/backup/business_data_wipe_service.dart';
const _appRepositoriesPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';

void main() {
  group('Phase 106AF business data wipe current-counts product read', () {
    test('counts active and inactive catalog rows by list length only',
        () async {
      final catalog = _RecordingCatalog([
        _catalogProduct(id: 'active', isActive: true),
        _catalogProduct(id: 'inactive', isActive: false),
      ]);
      final fixture = await _fixture(catalog);

      final result = await fixture.service.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isTrue);
      expect(catalog.includeInactiveValues, [true]);
      expect(result.wipedCounts!.products, 2);
      expect(
        result.wipedCounts,
        isA<BusinessDataWipeCounts>()
            .having((counts) => counts.inventoryMovements, 'movements', 0)
            .having((counts) => counts.suppliers, 'suppliers', 0)
            .having((counts) => counts.purchases, 'purchases', 0)
            .having((counts) => counts.sales, 'sales', 0)
            .having((counts) => counts.documentHistory, 'history', 0)
            .having((counts) => counts.customers, 'customers', 0)
            .having((counts) => counts.expenses, 'expenses', 0)
            .having((counts) => counts.auditLogs, 'audit logs', 0),
      );
      expect(fixture.products.listCalls, 0);
      expect(fixture.products.clearCalls, 1);
      expect(fixture.writer.saveCalls, 1);
      expect(await fixture.products.listProducts(), isEmpty);
    });

    test('catalog read failure preserves the existing no-delete failure path',
        () async {
      final fixture = await _fixture(const _ThrowingCatalog());

      final result = await fixture.service.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'backup-required-failed');
      expect(fixture.writer.saveCalls, 1);
      expect(fixture.products.listCalls, 0);
      expect(fixture.products.clearCalls, 0);
      expect(await fixture.products.listProducts(), hasLength(1));
    });
  });

  test('source guard freezes dependency, call, result use, wiring, and scope',
      () {
    final service = File(_servicePath).readAsStringSync();
    final currentCounts = _methodBody(
      service,
      'Future<BusinessDataWipeCounts> _currentCounts() async',
    );
    final compactService = _compact(service);
    final compactCounts = _compact(currentCounts);
    final appRepositories =
        _compact(File(_appRepositoriesPath).readAsStringSync());

    expect(
      compactService,
      contains(
        'requiredProductCatalogReadRepositoryproductCatalogReadRepository',
      ),
    );
    expect(
      compactService,
      contains(
        'finalProductCatalogReadRepository_productCatalogReadRepository;',
      ),
    );
    expect(
      compactCounts,
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true,)',
      ),
    );
    expect(currentCounts, isNot(contains('_productRepository.listProducts(')));
    expect(currentCounts, contains('products: products.length'));
    expect(RegExp(r'products\.').allMatches(currentCounts), hasLength(1));
    expect(service, contains('_productRepository.clearForOwnerDataWipe()'));
    expect(
      appRepositories,
      contains('productCatalogReadRepository:productCatalogReadRepository'),
    );

    final productionDiff = _git([
      'diff',
      '--name-only',
      _baseline,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((path) => path.isNotEmpty).toSet();
    expect(productionDiff, {_servicePath, _appRepositoriesPath});
    expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
    expect(
      _git([
        'diff',
        '--name-only',
        _baseline,
        '--',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/core/persistence',
      ]).trim(),
      isEmpty,
    );
  });

  test('live production inventory reconciles to 14 migrated and 10 remaining',
      () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 12);
    expect(_occurrences(joined, '.listProductCatalog('), 14);
    expect(
      sources[_servicePath],
      isNot(contains('_productRepository.listProducts(')),
    );
  });

  test('lineage is the Phase 106AE baseline or its sole Phase 106AF child', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
      expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _subject);
      expect(_git(['rev-list', '--count', '$_baseline..HEAD']).trim(), '1');
    }
  });
}

Future<_Fixture> _fixture(ProductCatalogReadRepository countCatalog) async {
  final products = _TrackingProductRepository();
  await products.createProduct(
    const ProductDraft(name: 'Stored product', unit: GrainUnit.kilogram),
  );
  final exportCatalog = _StaticCatalog([
    _catalogProduct(id: 'active', isActive: true),
    _catalogProduct(id: 'inactive', isActive: false),
  ]);
  final suppliers = LocalSupplierRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  final history = LocalDocumentHistoryRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    productCatalogReadRepository: exportCatalog,
    inventoryRepository: inventory,
  );
  final export = BackupExportService(
    productCatalogReadRepository: exportCatalog,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    now: () => DateTime.utc(2026, 8, 2, 12),
  );
  final writer = _RecordingFileWriter();
  final service = BusinessDataWipeService(
    backupExportService: export,
    backupFileWriter: writer,
    productRepository: products,
    productCatalogReadRepository: countCatalog,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
  );
  return _Fixture(service, products, writer);
}

ProductCatalogReadModel _catalogProduct({
  required String id,
  required bool isActive,
}) =>
    ProductCatalogReadModel(
      id: id,
      name: 'Catalog $id',
      code: null,
      unit: GrainUnit.kilogram,
      isActive: isActive,
      referenceCostPricePiastersPerKg: null,
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
      notes: null,
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
    );

final class _Fixture {
  const _Fixture(this.service, this.products, this.writer);

  final BusinessDataWipeService service;
  final _TrackingProductRepository products;
  final _RecordingFileWriter writer;
}

final class _TrackingProductRepository extends LocalProductRepository {
  int listCalls = 0;
  int clearCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) {
    listCalls++;
    return super.listProducts(includeInactive: includeInactive);
  }

  @override
  Future<void> clearForOwnerDataWipe() {
    clearCalls++;
    return super.clearForOwnerDataWipe();
  }
}

final class _RecordingCatalog implements ProductCatalogReadRepository {
  _RecordingCatalog(this.products);

  final List<ProductCatalogReadModel> products;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    includeInactiveValues.add(includeInactive);
    return products;
  }
}

final class _StaticCatalog implements ProductCatalogReadRepository {
  const _StaticCatalog(this.products);

  final List<ProductCatalogReadModel> products;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      products;
}

final class _ThrowingCatalog implements ProductCatalogReadRepository {
  const _ThrowingCatalog();

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) =>
      throw StateError('catalog read failed');
}

final class _RecordingFileWriter implements BackupFileWriter {
  int saveCalls = 0;

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async {
    saveCalls++;
    return BackupFileSaveResult(
      fileName: fileName,
      filePath: 'C:\\backups\\$fileName',
      folderPath: 'C:\\backups',
    );
  }
}

final _owner = AppUser(
  id: 'phase-106af-owner',
  name: 'Owner',
  phone: '01000000106',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll('\\', '/');
    sources[path] = entity.readAsStringSync();
  }
  return sources;
}

String _git(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    runInShell: false,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace: $declaration');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
