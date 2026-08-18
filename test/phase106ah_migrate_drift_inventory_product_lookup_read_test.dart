import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';

const _baseline = '25f4896b45fd8848a3aa5390e57a30926b9a9a24';
const _historicalScopeEndpoint = 'f521a97946d73829fef19f4f0d30a6d07b9f8051';
const _subject = 'PHASE 106AH: migrate drift inventory product lookup read';
const _phase106ahCommit = 'bd5d287a56fd96f826c673d775226cb4ad45a247';
const _phase106aiSubject =
    'PHASE 106AI: freeze next product read migration target';
const _repositoryPath = 'lib/core/inventory/drift_inventory_repository.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

void main() {
  group('Phase 106AH executable lookup behavior', () {
    test('uses an exact id, includes inactive rows, and returns not-found',
        () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final catalog = _CatalogSpy([
        _product('prd-exact', isActive: true),
        _product('prd-other', isActive: true),
      ]);
      final inventory = DriftInventoryRepository(
        database,
        productCatalogReadRepository: catalog,
      );

      expect(await inventory.currentStockKg('prd-exact'), 0);
      expect(catalog.includeInactive, [true]);

      await expectLater(
        inventory.currentStockKg('PRD-EXACT'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Product was not found.',
          ),
        ),
      );
      expect(catalog.includeInactive, [true, true]);
    });

    test('the first exact inactive match reaches the unchanged rejection',
        () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final catalog = _CatalogSpy([
        _product('prd-duplicate', isActive: false),
        _product('prd-duplicate', isActive: true),
      ]);
      final inventory = DriftInventoryRepository(
        database,
        productCatalogReadRepository: catalog,
      );

      await expectLater(
        inventory.createMovement(
          const StockMovementDraft(
            productId: 'prd-duplicate',
            movementType: StockMovementType.manualIncrease,
            quantityKg: 4,
            createdByUserId: 'phase-106ah',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Inactive product cannot accept stock movements.',
          ),
        ),
      );

      expect(catalog.includeInactive, [true]);
      expect(await database.select(database.inventoryMovements).get(), isEmpty);
      expect(
          await database.select(database.repositorySequences).get(), isEmpty);
    });

    test('catalog errors propagate once without fallback, retry, or writes',
        () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final sentinel = StateError('Phase 106AH catalog read sentinel');
      final catalog = _CatalogSpy(const [], error: sentinel);
      final inventory = DriftInventoryRepository(
        database,
        productCatalogReadRepository: catalog,
      );

      await expectLater(
        inventory.createMovement(
          const StockMovementDraft(
            productId: 'prd-error',
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1,
            createdByUserId: 'phase-106ah',
          ),
        ),
        throwsA(same(sentinel)),
      );

      expect(catalog.includeInactive, [true]);
      expect(await database.select(database.inventoryMovements).get(), isEmpty);
      expect(
          await database.select(database.repositorySequences).get(), isEmpty);
    });

    test('reads still precede the unchanged movement and sequence writes',
        () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final catalog = _CatalogSpy([_product('prd-write', isActive: true)]);
      catalog.beforeReturn = () async {
        expect(
          await database.select(database.inventoryMovements).get(),
          isEmpty,
        );
        expect(
          await database.select(database.repositorySequences).get(),
          isEmpty,
        );
      };
      final inventory = DriftInventoryRepository(
        database,
        productCatalogReadRepository: catalog,
      );

      final movement = await inventory.createMovement(
        const StockMovementDraft(
          productId: 'prd-write',
          movementType: StockMovementType.manualIncrease,
          quantityKg: 7,
          createdByUserId: 'phase-106ah',
        ),
      );

      expect(catalog.includeInactive, [true, true]);
      expect(movement.productId, 'prd-write');
      expect(movement.quantityKg, 7);
      expect(await database.select(database.inventoryMovements).get(),
          hasLength(1));
      final sequence =
          (await database.select(database.repositorySequences).get()).single;
      expect(sequence.repository, 'inventory_movements');
      expect(sequence.nextValue, 2);
    });
  });

  group('Phase 106AH architecture and lineage guards', () {
    test('repository constructor and lookup use only the catalog read contract',
        () {
      final source = File(_repositoryPath).readAsStringSync();
      final constructor = _between(
        source,
        'DriftInventoryRepository(',
        'static const _sequenceKey',
      );
      final lookup = _methodBody(
        source,
        'Future<ProductCatalogReadModel?> _findProductById(String id) async',
      );

      expect(source, isNot(contains('product_repository.dart')));
      expect(source, isNot(contains('ProductRepository')));
      expect(source, isNot(contains('_productRepository')));
      expect(constructor, contains('required ProductCatalogReadRepository'));
      expect(
        _compact(lookup),
        contains(
          '_productCatalogReadRepository.listProductCatalog('
          'includeInactive:true,)',
        ),
      );
      expect(lookup, contains('if (product.id == id) return product;'));
      expect(lookup, contains('return null;'));
      expect(lookup, isNot(contains('try')));
      expect(lookup, isNot(contains('catch')));
    });

    test('production composition passes only the catalog lookup dependency',
        () {
      final source = File(_compositionPath).readAsStringSync();
      final compact = _compact(source);

      expect(
        compact,
        contains(
          '_inventoryRepository=DriftInventoryRepository('
          'database,productCatalogReadRepository:'
          'productCatalogReadRepository,)',
        ),
      );
      expect(
        compact,
        isNot(
          contains(
            'DriftInventoryRepository('
            'database,productRepository:productRepository,',
          ),
        ),
      );
    });

    test('contract, adapter, schema, and generated files are unchanged', () {
      expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
      expect(_git(['diff', _baseline, '--', _adapterPath]).trim(), isEmpty);
      final changed = _git([
        'diff',
        '--name-only',
        _baseline,
        _historicalScopeEndpoint,
        '--',
        'lib',
      ]).split(RegExp(r'\r?\n'))
        ..removeWhere(
          (path) => path.isEmpty || _isPhase107GProductionPath(path),
        );
      expect(changed.toSet(), {
        _repositoryPath,
        _compositionPath,
        'lib/core/backup/backup_checksum.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/backup/backup_restore_preview.dart',
        'lib/core/backup/business_data_wipe_service.dart',
        'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
        'lib/core/inventory_valuation/profitability_activation_service.dart',
        'lib/core/purchases/drift_purchase_repository.dart',
        'lib/core/sales/drift_sale_repository.dart',
        'lib/core/sales/sale_repository.dart',
      });
    });

    test('production inventory is 19 migrated, 5 remaining, F0/I5', () {
      final sources = _dartSources().values.join('\n');
      expect(_occurrences(sources, '.listProducts('), 6);
      expect(_occurrences(sources, '.listProductCatalog('), 20);
    });

    test('lineage is the baseline or its single Phase 106AH child', () {
      final head = _git(['rev-parse', 'HEAD']).trim();
      if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
              .trim() ==
          'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
      if (head == _baseline) return;
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106ah = subject == _subject &&
          _git(['rev-parse', 'HEAD^']).trim() == _baseline;
      final atPhase106ai = subject == _phase106aiSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106ahCommit;
      final atPhase106aj = subject ==
              'PHASE 106AJ: migrate drift purchase product validation reads' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              '7acac87799fc8345671f356cce273d345c38b565';
      final atPhase106ak =
          subject == 'PHASE 106AK: freeze next product read migration target' &&
              _git(['rev-parse', 'HEAD^']).trim() ==
                  '2fd2ef4519b1007f1080fe004cca8572c1fe0d54';
      final atPhase106al = subject ==
              'PHASE 106AL: migrate negative balance approval product fingerprint read' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
      final atPhase106am = subject ==
              'PHASE 106AM: migrate profitability activation product read' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
      final atPhase106an =
          subject == 'Phase 106AN: migrate PRC-111 product read' &&
              _git(['rev-parse', 'HEAD^']).trim() ==
                  '8802c2115a45785f8705764514f9c7d0250a050d';
      expect(
        atPhase106ah ||
            atPhase106ai ||
            atPhase106aj ||
            atPhase106ak ||
            atPhase106al ||
            atPhase106am ||
            atPhase106an,
        isTrue,
      );
      expect(
        _git(['rev-list', '--count', '$_baseline..HEAD']).trim(),
        atPhase106an
            ? '7'
            : atPhase106am
                ? '6'
                : atPhase106al
                    ? '5'
                    : (atPhase106ak
                        ? '4'
                        : (atPhase106aj ? '3' : (atPhase106ai ? '2' : '1'))),
      );
    });
  });
}

bool _isPhase107GProductionPath(String path) =>
    path == 'lib/main.dart' ||
    path.startsWith('lib/core/trial/') ||
    path.startsWith('lib/features/trial/');

final class _CatalogSpy implements ProductCatalogReadRepository {
  _CatalogSpy(this.products, {this.error});

  final List<ProductCatalogReadModel> products;
  final Object? error;
  final List<bool> includeInactive = [];
  Future<void> Function()? beforeReturn;

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    this.includeInactive.add(includeInactive);
    final callback = beforeReturn;
    if (callback != null) await callback();
    final failure = error;
    if (failure != null) throw failure;
    return products;
  }
}

ProductCatalogReadModel _product(String id, {required bool isActive}) {
  final timestamp = DateTime.utc(2026, 8, 3);
  return ProductCatalogReadModel(
    id: id,
    name: id,
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll('\\', '/')] = entity.readAsStringSync();
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

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Expected source boundaries were not found.');
  }
  return source.substring(startIndex, endIndex);
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
