import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

const _baseline = '1cd4033720fd765a31b5b5357760c8f55e454f92';
const _subject =
    'PHASE 106AD: migrate backup restore empty-system product read';
const _phase106adCommit = 'd7e7dcd21644e2f4946458b4394e94679454c932';
const _phase106aeSubject =
    'PHASE 106AE: freeze next product read migration target';
const _servicePath = 'lib/core/backup/backup_restore_service.dart';
const _appRepositoriesPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';

void main() {
  group('Phase 106AD backup restore empty-system product read', () {
    test('active catalog product makes the system non-empty', () async {
      final catalog = _RecordingCatalog([_product(isActive: true)]);
      final fixture = await _fixture(catalog);

      final result = await fixture.service.restoreToEmpty(
        user: _owner,
        jsonText: fixture.emptyBackup,
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'system-not-empty');
      expect(catalog.includeInactiveValues, [true]);
    });

    test('inactive-only catalog product also makes the system non-empty',
        () async {
      final catalog = _RecordingCatalog([_product(isActive: false)]);
      final fixture = await _fixture(catalog);

      final result = await fixture.service.restoreToEmpty(
        user: _owner,
        jsonText: fixture.emptyBackup,
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'system-not-empty');
      expect(catalog.includeInactiveValues, [true]);
    });

    test('empty catalog allows the unchanged remaining checks to complete',
        () async {
      final catalog = _RecordingCatalog(const []);
      final fixture = await _fixture(catalog);

      final result = await fixture.service.restoreToEmpty(
        user: _owner,
        jsonText: fixture.emptyBackup,
      );

      expect(result.success, isTrue);
      expect(catalog.includeInactiveValues, [true]);
    });
  });

  test('source guard freezes dependency, call, list-only use, and scope', () {
    final service = File(_servicePath).readAsStringSync();
    final compactService = _compact(service);
    final check = _methodBody(
      service,
      'Future<String?> _checkEmptySystem() async',
    );
    final compactCheck = _compact(check);
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
      compactCheck,
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true,)',
      ),
    );
    expect(
      compactCheck,
      isNot(contains('_productRepository.listProducts(')),
    );
    expect(check, contains('products.isNotEmpty'));
    expect(RegExp(r'products\.').allMatches(check), hasLength(1));
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

  test('lineage is the frozen Phase 106AC baseline or its sole 106AD child',
      () {
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106ad = subject == _subject &&
          _git(['rev-parse', 'HEAD^']).trim() == _baseline;
      final atPhase106ae = subject == _phase106aeSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106adCommit;
      expect(atPhase106ad || atPhase106ae, isTrue);
      expect(
        _git(['rev-list', '--count', '$_baseline..HEAD']).trim(),
        atPhase106ae ? '2' : '1',
      );
    }
  });
}

Future<_Fixture> _fixture(ProductCatalogReadRepository catalog) async {
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
  final export = BackupExportService(
    productCatalogReadRepository: const _StaticCatalog(),
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    inventoryValuationRepository: valuation,
    now: () => DateTime.utc(2026, 8, 2, 12),
  );
  final backup = await export.createBackup();
  final service = BackupRestoreService(
    productRepository: products,
    productCatalogReadRepository: catalog,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    inventoryValuationRepository: valuation,
  );
  return _Fixture(service, backup.jsonText);
}

ProductCatalogReadModel _product({required bool isActive}) =>
    ProductCatalogReadModel(
      id: 'catalog-product',
      name: 'Catalog product',
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
  const _Fixture(this.service, this.emptyBackup);

  final BackupRestoreService service;
  final String emptyBackup;
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
  const _StaticCatalog();

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      const [];
}

final _owner = AppUser(
  id: 'phase-106ad-owner',
  name: 'Owner',
  phone: '01000000106',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

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

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
