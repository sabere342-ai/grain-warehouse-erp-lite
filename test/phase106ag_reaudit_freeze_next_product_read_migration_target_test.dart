import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = 'b786e0869808182614ba301af4fdd615124d7a8e';
const _subject = 'PHASE 106AG: freeze next product read migration target';
const _predecessorSubject =
    'PHASE 106AF: migrate business data wipe current counts product read';
const _reportPath =
    'docs/PHASE-106AG-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _predecessorReportPath =
    'docs/PHASE-106AF-MIGRATE-BUSINESS-DATA-WIPE-CURRENT-COUNTS-PRODUCT-READ.md';
const _predecessorGuardPath =
    'test/phase106af_migrate_business_data_wipe_current_counts_product_read_test.dart';
const _targetPath = 'lib/core/inventory/drift_inventory_repository.dart';
const _appRepositoriesPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

const _migrated = <String, _Consumer>{
  'PRC-001': _Consumer('lib/core/documents/document_history.dart', 1),
  'PRC-002': _Consumer('lib/features/dashboard/dashboard_screen.dart', 1),
  'PRC-003':
      _Consumer('lib/core/inventory/inventory_attention_service.dart', 1),
  'PRC-004': _Consumer('lib/core/dashboard/dashboard_service.dart', 1),
  'PRC-010': _Consumer(_targetPath, 1),
  'PRC-014': _Consumer('lib/core/reports/report_repository.dart', 1),
  'PRC-101': _Consumer('lib/core/backup/backup_export.dart', 1),
  'PRC-102': _Consumer('lib/core/backup/backup_restore_service.dart', 1),
  'PRC-103': _Consumer('lib/core/backup/business_data_wipe_service.dart', 1),
  'PRC-104': _Consumer('lib/core/catalog/product_controller.dart', 1),
  'PRC-107': _Consumer('lib/core/inventory/inventory_controller.dart', 1),
  'PRC-110': _Consumer('lib/core/purchases/purchase_controller.dart', 1),
  'PRC-112': _Consumer('lib/core/sales/sale_controller.dart', 1),
  'PRC-113': _Consumer(
    'lib/features/financial_reports/profitability_report_screen.dart',
    1,
  ),
};

const _remaining = <String, _Consumer>{
  'PRC-105': _Consumer(
    'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
    1,
    classification: 'F',
  ),
  'PRC-106': _Consumer(_targetPath, 1, classification: 'F'),
  'PRC-108': _Consumer(
    'lib/core/inventory_valuation/profitability_activation_service.dart',
    1,
    classification: 'F',
  ),
  'PRC-109': _Consumer(
    'lib/core/purchases/drift_purchase_repository.dart',
    2,
    classification: 'F',
  ),
  'PRC-111': _Consumer(
    'lib/core/sales/sale_repository.dart',
    1,
    classification: 'F',
  ),
  'PRC-114': _Consumer(
    'lib/core/inventory/inventory_repository.dart',
    2,
    classification: 'I',
  ),
  'PRC-115': _Consumer(
    'lib/core/purchases/purchase_repository.dart',
    1,
    classification: 'I',
  ),
  'PRC-116': _Consumer(
    'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
    1,
    classification: 'I',
  ),
  'PRC-117': _Consumer(
    'lib/app/app_repositories.dart',
    1,
    classification: 'I',
  ),
  'PRC-118': _Consumer(
    'lib/core/catalog/drift_product_repository.dart',
    1,
    classification: 'I',
  ),
};

const _selectedTargets = {'PRC-106'};
const _expectedPhase106ahProductionFiles = {
  _targetPath,
  _appRepositoriesPath,
};

void main() {
  test('baseline lineage and direct Phase 106AF predecessor are exact', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(
      _git(['log', '-1', '--format=%s', _baseline]).trim(),
      _predecessorSubject,
    );
    expect(File(_predecessorReportPath).existsSync(), isTrue);
    expect(File(_predecessorGuardPath).existsSync(), isTrue);

    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
      expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _subject);
      expect(_git(['rev-list', '--count', '$_baseline..HEAD']).trim(), '1');
    }
  });

  test('inventory has 24 unique PRCs: 14 migrated and 10 remaining', () {
    expect(_migrated, hasLength(14));
    expect(_remaining, hasLength(10));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
      _migrated.keys.toSet().intersection(_remaining.keys.toSet()),
      isEmpty,
    );
  });

  test('remaining classification is exactly F5 and I5', () {
    final counts = <String, int>{
      for (final category in 'ABCDEFGHI'.split('')) category: 0,
    };
    for (final consumer in _remaining.values) {
      counts[consumer.classification] = counts[consumer.classification]! + 1;
    }
    expect(counts, {
      'A': 0,
      'B': 0,
      'C': 0,
      'D': 0,
      'E': 0,
      'F': 5,
      'G': 0,
      'H': 0,
      'I': 5,
    });
  });

  test('production has exactly 12 legacy and 14 catalog calls', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 12);
    expect(_occurrences(joined, '.listProductCatalog('), 14);

    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProducts('))
          .map((entry) => entry.key)
          .toSet(),
      {for (final consumer in _remaining.values) consumer.path},
    );
    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProductCatalog('))
          .map((entry) => entry.key)
          .toSet(),
      {for (final consumer in _migrated.values) consumer.path},
    );
    for (final consumer in _remaining.values) {
      expect(
        _occurrences(sources[consumer.path]!, '.listProducts('),
        consumer.callSites,
        reason: consumer.path,
      );
    }
    for (final consumer in _migrated.values) {
      expect(
        _occurrences(sources[consumer.path]!, '.listProductCatalog('),
        consumer.callSites,
        reason: consumer.path,
      );
    }
  });

  test('PRC-106 is exactly one frozen target and remains legacy in 106AG', () {
    expect(_selectedTargets, hasLength(1));
    expect(_selectedTargets.single, 'PRC-106');
    expect(_remaining, contains(_selectedTargets.single));

    final source = File(_targetPath).readAsStringSync();
    final helper = _methodBody(
      source,
      'Future<Product?> _findProductById(String id) async',
    );
    expect(
      _compact(helper),
      contains(
        '_productRepository.listProducts(includeInactive:true)',
      ),
    );
    expect(helper, isNot(contains('.listProductCatalog(')));
    expect(helper, contains('if (product.id == id) return product;'));
    expect(helper, contains('return null;'));
    expect(_occurrences(helper, '.listProducts('), 1);
    expect(source, contains('if (!product.isActive)'));
    expect(
      source,
      contains('Inactive product cannot accept stock movements.'),
    );
  });

  test('proposed call, fields, composition, and exact AH scope are frozen', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'FROZEN_TARGET_ID: PRC-106',
      'FROZEN_TARGET_CONSUMER: DriftInventoryRepository._findProductById',
      'Current call: _productRepository.listProducts(includeInactive: true)',
      'Proposed call: _productCatalogReadRepository.listProductCatalog(includeInactive: true)',
      'Required includeInactive: true',
      'Fields consumed: id; isActive is consumed by _validateDraftAndLoadProduct',
      'Contract expansion: none',
      'Composition location: AppRepositories.initializeProduction, DriftInventoryRepository construction',
      'Legacy repository retained or removed: removed from DriftInventoryRepository constructor and field',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final scope = _between(
      report,
      '## M. Expected Production Scope for Next Phase',
      '## N. Risks and Explicit Exclusions',
    );
    final productionPaths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(scope)
        .map((match) => match.group(0)!)
        .toSet();
    expect(productionPaths, _expectedPhase106ahProductionFiles);

    final appRepositories = File(_appRepositoriesPath).readAsStringSync();
    expect(
      _compact(appRepositories),
      contains(
        '_inventoryRepository=DriftInventoryRepository('
        'database,productRepository:productRepository,'
        'productCatalogReadRepository:productCatalogReadRepository,)',
      ),
    );
  });

  test('report contains each PRC once and reconciles all governing counts', () {
    final report = File(_reportPath).readAsStringSync();
    final inventory = _between(
      report,
      '## E. Full Inventory',
      '## F. Migrated Consumers',
    );
    final rows = RegExp(r'^\| PRC-\d{3} \|', multiLine: true)
        .allMatches(inventory)
        .toList();
    expect(rows, hasLength(24));
    for (final id in [..._migrated.keys, ..._remaining.keys]) {
      expect(_occurrences(inventory, '| $id |'), 1, reason: id);
    }
    for (final statement in const [
      'Total consumers: 24',
      'Migrated: 14',
      'Remaining: 10',
      'Legacy calls: 12',
      'Product Catalog calls: 14',
      'F: 5 — PRC-105, PRC-106, PRC-108, PRC-109, PRC-111',
      'I: 5 — PRC-114, PRC-115, PRC-116, PRC-117, PRC-118',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('Phase 106AG has no production diff or contract/adapter change', () {
    expect(_git(['diff', _baseline, '--', 'lib']).trim(), isEmpty);
    expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
    expect(_git(['diff', _baseline, '--', _adapterPath]).trim(), isEmpty);
  });
}

final class _Consumer {
  const _Consumer(
    this.path,
    this.callSites, {
    this.classification = 'Accepted',
  });

  final String path;
  final int callSites;
  final String classification;
}

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
