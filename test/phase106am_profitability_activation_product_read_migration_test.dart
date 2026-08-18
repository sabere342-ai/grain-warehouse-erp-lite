import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/profitability_activation_service.dart';

const _baseline = 'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
const _historicalScopeEndpoint = 'f521a97946d73829fef19f4f0d30a6d07b9f8051';
const _baselineSubject =
    'PHASE 106AL: migrate negative balance approval product fingerprint read';
const _subject = 'PHASE 106AM: migrate profitability activation product read';
const _phase106amCommit = '8802c2115a45785f8705764514f9c7d0250a050d';
const _phase106anSubject = 'Phase 106AN: migrate PRC-111 product read';
const _targetPath =
    'lib/core/inventory_valuation/profitability_activation_service.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _reportPath =
    'docs/PHASE-106AM-PROFITABILITY-ACTIVATION-PRODUCT-READ-MIGRATION.md';

void main() {
  test('PRC-108 depends only on the canonical product catalog read contract',
      () {
    final source = File(_targetPath).readAsStringSync();
    final activate = _methodBody(
      source,
      'Future<void> activate({',
    );

    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('.listProducts(')));
    expect(_occurrences(source, '.listProductCatalog('), 1);
    expect(
      _compact(activate),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(activate, contains('inputByProduct.length != products.length'));
    expect(activate, contains('products.map((product) => product.id).toSet()'));
    expect(activate, contains('for (final product in products)'));
    expect(
      activate,
      contains(
          'products.map((product) => inputByProduct[product.id]!).toList()'),
    );

    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('final String id;'));
    expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
  });

  test('production composition injects the canonical catalog repository', () {
    final source = File(_compositionPath).readAsStringSync();
    final construction = _construction(
      source,
      'ProfitabilityActivationService(',
    );
    expect(
      construction,
      contains('productCatalogReadRepository: productCatalogReadRepository'),
    );
    expect(construction, isNot(contains('productRepository:')));
  });

  test('canonical snapshot preserves inactive membership and stable order',
      () async {
    final catalog = _CatalogSpy([_model('second', false), _model('first')]);
    final inventory = _RecordingInventory({'second': 0, 'first': 0});
    final valuation = LocalInventoryValuationRepository();
    final audit = LocalAuditLogRepository();
    final service = _service(
      catalog: catalog,
      inventory: inventory,
      valuation: valuation,
      audit: audit,
    );

    await service.activate(
      user: _owner,
      activationDate: DateTime(2026, 8, 1),
      evidenceNote: '  PHYSICAL COUNT  ',
      openings: const [
        OpeningValuationInput(
          productId: 'first',
          quantityKg: 0,
          unitCostQirshPerKg: 0,
          evidenceReference: 'FIRST-EVIDENCE',
        ),
        OpeningValuationInput(
          productId: 'second',
          quantityKg: 0,
          unitCostQirshPerKg: 0,
          evidenceReference: 'SECOND-EVIDENCE',
        ),
      ],
    );

    expect(catalog.includeInactiveValues, [true]);
    expect(inventory.stockReadIds, ['second', 'first']);
    expect(
      (await valuation.listStates()).map((state) => state.productId),
      ['second', 'first'],
    );
    expect((await valuation.getActivation()).evidenceNote, 'PHYSICAL COUNT');
    final logs = await audit.exportStoredAuditLogs();
    expect(logs.single.metadata['productCount'], 2);
  });

  test('incomplete canonical snapshot decision causes no writes or stock reads',
      () async {
    final catalog = _CatalogSpy([_model('first'), _model('second')]);
    final inventory = _RecordingInventory({'first': 0, 'second': 0});
    final valuation = LocalInventoryValuationRepository();
    final audit = LocalAuditLogRepository();
    final service = _service(
      catalog: catalog,
      inventory: inventory,
      valuation: valuation,
      audit: audit,
    );

    await expectLater(
      service.activate(
        user: _owner,
        activationDate: DateTime(2026, 8, 1),
        evidenceNote: 'PHYSICAL COUNT',
        openings: const [
          OpeningValuationInput(
            productId: 'first',
            quantityKg: 0,
            unitCostQirshPerKg: 0,
            evidenceReference: 'FIRST-EVIDENCE',
          ),
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Every existing product requires an opening decision.',
        ),
      ),
    );

    expect(catalog.includeInactiveValues, [true]);
    expect(inventory.stockReadIds, isEmpty);
    expect((await valuation.getActivation()).isActivated, isFalse);
    expect(await valuation.listStates(), isEmpty);
    expect(await audit.exportStoredAuditLogs(), isEmpty);
  });

  test('catalog read errors propagate before financial or audit writes',
      () async {
    final valuation = LocalInventoryValuationRepository();
    final audit = LocalAuditLogRepository();
    final service = _service(
      catalog: _ThrowingCatalog(),
      inventory: _RecordingInventory(const {}),
      valuation: valuation,
      audit: audit,
    );

    await expectLater(
      service.activate(
        user: _owner,
        activationDate: DateTime(2026, 8, 1),
        evidenceNote: 'PHYSICAL COUNT',
        openings: const [],
      ),
      throwsA(isA<StateError>()),
    );
    expect((await valuation.getActivation()).isActivated, isFalse);
    expect(await audit.exportStoredAuditLogs(), isEmpty);
  });

  test('inventory moves only PRC-108 from legacy to canonical reads', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 6);
    expect(_occurrences(joined, '.listProductCatalog('), 20);
    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProducts('))
          .map((entry) => entry.key)
          .toSet(),
      {
        'lib/app/app_repositories.dart',
        'lib/core/catalog/drift_product_repository.dart',
        'lib/core/inventory/inventory_repository.dart',
        'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
        'lib/core/purchases/purchase_repository.dart',
      },
    );
  });

  test(
      'production scope is exactly PRC-108 and composition with no schema diff',
      () {
    final changedProduction = _git([
      'diff',
      '--name-only',
      _baseline,
      _historicalScopeEndpoint,
      '--',
      'lib',
    ])
        .trim()
        .split(RegExp(r'\r?\n'))
        .where((path) => path.isNotEmpty && !_isPhase107GProductionPath(path))
        .toSet();
    expect(changedProduction, {
      _targetPath,
      _compositionPath,
      'lib/core/backup/backup_checksum.dart',
      'lib/core/backup/backup_export.dart',
      'lib/core/backup/backup_restore_preview.dart',
      'lib/core/backup/business_data_wipe_service.dart',
      'lib/core/sales/drift_sale_repository.dart',
      'lib/core/sales/sale_repository.dart',
    });
    expect(
      _git(['diff', _baseline, '--', 'lib/core/persistence']).trim(),
      isEmpty,
    );
    for (final path in changedProduction) {
      expect(path, isNot(contains('.g.dart')));
      expect(path, isNot(contains('migration')));
    }
    expect(File(_reportPath).existsSync(), isTrue);
  });

  test('lineage preserves the exact Phase 106AM and 106AN children', () {
    expect(
      _git(['merge-base', '--is-ancestor', _phase106amCommit, 'HEAD']),
      isEmpty,
    );
    expect(
      _git(['log', '-1', '--format=%s', _baseline]).trim(),
      _baselineSubject,
    );
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
            .trim() ==
        'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
    if (head == _baseline) return;
    if (head == _phase106amCommit) {
      expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
      expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _subject);
      return;
    }
    expect(_git(['rev-parse', 'HEAD^']).trim(), _phase106amCommit);
    expect(
      _git(['log', '-1', '--format=%s', 'HEAD']).trim(),
      _phase106anSubject,
    );
    expect(_git(['rev-list', '--count', '$_baseline..HEAD']).trim(), '2');
  });
}

bool _isPhase107GProductionPath(String path) =>
    path == 'lib/main.dart' ||
    path.startsWith('lib/core/trial/') ||
    path.startsWith('lib/features/trial/');

ProfitabilityActivationService _service({
  required ProductCatalogReadRepository catalog,
  required InventoryRepository inventory,
  required LocalInventoryValuationRepository valuation,
  required LocalAuditLogRepository audit,
}) =>
    ProfitabilityActivationService(
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      valuationRepository: valuation,
      auditLogRepository: audit,
      clock: () => DateTime(2026, 8, 8, 12),
    );

final _owner = AppUser(
  id: 'owner-phase106am',
  name: 'Phase 106AM owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProductCatalogReadModel _model(String id, [bool isActive = true]) =>
    ProductCatalogReadModel(
      id: id,
      name: id,
      code: null,
      unit: GrainUnit.kilogram,
      isActive: isActive,
      referenceCostPricePiastersPerKg: null,
      defaultSalePricePiastersPerKg: null,
      minimumSalePricePiastersPerKg: null,
      notes: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

final class _CatalogSpy implements ProductCatalogReadRepository {
  _CatalogSpy(this.values);

  final List<ProductCatalogReadModel> values;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    includeInactiveValues.add(includeInactive);
    return values;
  }
}

final class _ThrowingCatalog implements ProductCatalogReadRepository {
  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) =>
      throw StateError('catalog read failed');
}

final class _RecordingInventory implements InventoryRepository {
  _RecordingInventory(this.balances);

  final Map<String, int> balances;
  final List<String> stockReadIds = [];

  @override
  Future<int> currentStockKg(String productId) async {
    stockReadIds.add(productId);
    return balances[productId] ?? 0;
  }

  @override
  Future<Map<String, int>> allProductBalancesKg({
    bool activeProductsOnly = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) =>
      throw UnimplementedError();

  @override
  Future<bool> hasOpeningBalance(String productId) =>
      throw UnimplementedError();

  @override
  Future<List<StockMovement>> listAllMovements() => throw UnimplementedError();

  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) =>
      throw UnimplementedError();
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll('\\', '/')] = entity.readAsStringSync();
  }
  return sources;
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final asyncStart = source.indexOf(' async', start);
  if (asyncStart < 0) throw StateError('Missing async body: $declaration');
  final openBrace = source.indexOf('{', asyncStart);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace: $declaration');
}

String _construction(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) throw StateError('Missing construction: $marker');
  var depth = 0;
  var opened = false;
  for (var index = start; index < source.length; index++) {
    if (source[index] == '(') {
      depth++;
      opened = true;
    }
    if (source[index] == ')') depth--;
    if (opened && depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing construction close: $marker');
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

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
