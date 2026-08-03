import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = 'd7e7dcd21644e2f4946458b4394e94679454c932';
const _subject = 'PHASE 106AE: freeze next product read migration target';
const _phase106aeCommit = '1d1b24afac39fe3e83704aa73747568c2c9b525c';
const _phase106afSubject =
    'PHASE 106AF: migrate business data wipe current counts product read';
const _phase106afCommit = 'b786e0869808182614ba301af4fdd615124d7a8e';
const _phase106agSubject =
    'PHASE 106AG: freeze next product read migration target';
const _phase106agCommit = '25f4896b45fd8848a3aa5390e57a30926b9a9a24';
const _phase106ahSubject =
    'PHASE 106AH: migrate drift inventory product lookup read';
const _phase106ahCommit = 'bd5d287a56fd96f826c673d775226cb4ad45a247';
const _phase106aiSubject =
    'PHASE 106AI: freeze next product read migration target';
const _reportPath =
    'docs/PHASE-106AE-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _restorePath = 'lib/core/backup/backup_restore_service.dart';
const _targetPath = 'lib/core/backup/business_data_wipe_service.dart';
const _appRepositoriesPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';

const _migrated = <String, _Consumer>{
  'PRC-001': _Consumer('lib/core/documents/document_history.dart', 1),
  'PRC-002': _Consumer('lib/features/dashboard/dashboard_screen.dart', 1),
  'PRC-003':
      _Consumer('lib/core/inventory/inventory_attention_service.dart', 1),
  'PRC-004': _Consumer('lib/core/dashboard/dashboard_service.dart', 1),
  'PRC-010': _Consumer('lib/core/inventory/drift_inventory_repository.dart', 1),
  'PRC-014': _Consumer('lib/core/reports/report_repository.dart', 1),
  'PRC-101': _Consumer('lib/core/backup/backup_export.dart', 1),
  'PRC-102': _Consumer(_restorePath, 1),
  'PRC-103': _Consumer(_targetPath, 1),
  'PRC-104': _Consumer('lib/core/catalog/product_controller.dart', 1),
  'PRC-106': _Consumer('lib/core/inventory/drift_inventory_repository.dart', 1),
  'PRC-107': _Consumer('lib/core/inventory/inventory_controller.dart', 1),
  'PRC-110': _Consumer('lib/core/purchases/purchase_controller.dart', 1),
  'PRC-112': _Consumer('lib/core/sales/sale_controller.dart', 1),
  'PRC-113': _Consumer(
    'lib/features/financial_reports/profitability_report_screen.dart',
    1,
  ),
  'PRC-109': _Consumer(
    'lib/core/purchases/drift_purchase_repository.dart',
    2,
  ),
};

const _remaining = <String, _Consumer>{
  'PRC-105': _Consumer(
    'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
    1,
    classification: 'F',
  ),
  'PRC-108': _Consumer(
    'lib/core/inventory_valuation/profitability_activation_service.dart',
    1,
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

const _selectedTargets = ['PRC-103'];
const _requiredTargetFields = <String>[];
const _expectedProductionFiles = {
  _targetPath,
  _appRepositoriesPath,
};
const _forbiddenProductionPaths = {
  'lib/core/catalog/product_catalog_read_repository.dart',
  'lib/core/catalog/drift_product_catalog_read_repository.dart',
  'lib/core/persistence',
};

void main() {
  test('Phase 106AF is the sole migration child of the frozen 106AE audit', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _phase106aeCommit) {
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106af = subject == _phase106afSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106aeCommit;
      final atPhase106ag = subject == _phase106agSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106afCommit;
      final atPhase106ah = subject == _phase106ahSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106agCommit;
      final atPhase106ai = subject == _phase106aiSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106ahCommit;
      final atPhase106aj = subject ==
              'PHASE 106AJ: migrate drift purchase product validation reads' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              '7acac87799fc8345671f356cce273d345c38b565';
      expect(
        atPhase106af ||
            atPhase106ag ||
            atPhase106ah ||
            atPhase106ai ||
            atPhase106aj,
        isTrue,
      );
      expect(
        _git(['rev-list', '--count', '$_phase106aeCommit..HEAD']).trim(),
        atPhase106aj
            ? '5'
            : (atPhase106ai
                ? '4'
                : (atPhase106ah ? '3' : (atPhase106ag ? '2' : '1'))),
      );
    }
    expect(
        _git(['log', '-1', '--format=%s', _phase106aeCommit]).trim(), _subject);
    final productionDiff = _git([
      'diff',
      '--name-only',
      _phase106aeCommit,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((path) => path.isNotEmpty).toSet();
    expect(productionDiff, {
      ..._expectedProductionFiles,
      'lib/core/inventory/drift_inventory_repository.dart',
      'lib/core/purchases/drift_purchase_repository.dart',
    });
  });

  test('inventory has 24 unique consumers: 16 migrated and 8 remaining', () {
    expect(_migrated, hasLength(16));
    expect(_remaining, hasLength(8));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
      _migrated.keys.toSet().intersection(_remaining.keys.toSet()),
      isEmpty,
    );
    expect(_migrated.containsKey('PRC-102'), isTrue);
    expect(_remaining.containsKey('PRC-102'), isFalse);
  });

  test('remaining classifications reconcile exactly as F3 and I5', () {
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
      'F': 3,
      'G': 0,
      'H': 0,
      'I': 5,
    });
  });

  test('production discovery finds exactly 9 legacy and 17 catalog calls', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 9);
    expect(_occurrences(joined, '.listProductCatalog('), 17);

    final actualLegacyFiles = sources.entries
        .where((entry) => entry.value.contains('.listProducts('))
        .map((entry) => entry.key)
        .toSet();
    final actualCatalogFiles = sources.entries
        .where((entry) => entry.value.contains('.listProductCatalog('))
        .map((entry) => entry.key)
        .toSet();
    expect(
        actualLegacyFiles, {for (final value in _remaining.values) value.path});
    expect(
        actualCatalogFiles, {for (final value in _migrated.values) value.path});

    for (final entry in _callsByPath(_remaining).entries) {
      expect(
        _occurrences(sources[entry.key]!, '.listProducts('),
        entry.value,
        reason: entry.key,
      );
    }
    for (final entry in _callsByPath(_migrated).entries) {
      expect(
        _occurrences(sources[entry.key]!, '.listProductCatalog('),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('PRC-102 remains catalog-only with exact empty-system semantics', () {
    final source = File(_restorePath).readAsStringSync();
    final method = _methodBody(
      source,
      'Future<String?> _checkEmptySystem() async',
    );
    expect(
      _compact(method),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true,)',
      ),
    );
    expect(method, contains('products.isNotEmpty'));
    expect(RegExp(r'products\.').allMatches(method), hasLength(1));
    expect(method, isNot(contains('_productRepository.listProducts(')));
    expect(
      _compact(source),
      contains(
        'requiredProductCatalogReadRepositoryproductCatalogReadRepository',
      ),
    );
    expect(
      _compact(File(_appRepositoriesPath).readAsStringSync()),
      contains('productCatalogReadRepository:productCatalogReadRepository'),
    );
  });

  test('PRC-103 is the sole frozen target migrated by Phase 106AF', () {
    expect(_selectedTargets, hasLength(1));
    expect(_migrated, contains(_selectedTargets.single));
    expect(_remaining, isNot(contains(_selectedTargets.single)));

    final source = File(_targetPath).readAsStringSync();
    final method = _methodBody(
      source,
      'Future<BusinessDataWipeCounts> _currentCounts() async',
    );
    expect(
      _compact(method),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true,)',
      ),
    );
    expect(method, contains('products: products.length'));
    expect(RegExp(r'products\.').allMatches(method), hasLength(1));
    expect(method, isNot(contains('_productRepository.listProducts(')));
    expect(
      _compact(source),
      contains(
        'requiredProductCatalogReadRepositoryproductCatalogReadRepository',
      ),
    );
    expect(source, contains('final ProductDataRepository _productRepository;'));
    expect(source, contains('_productRepository.clearForOwnerDataWipe()'));
    expect(_requiredTargetFields, isEmpty);
  });

  test('target contract and the closed future production scope are frozen', () {
    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('required bool includeInactive'));
    expect(_expectedProductionFiles, {
      'lib/core/backup/business_data_wipe_service.dart',
      'lib/app/app_repositories.dart',
    });
    expect(_forbiddenProductionPaths, {
      'lib/core/catalog/product_catalog_read_repository.dart',
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
      'lib/core/persistence',
    });
  });

  test('report carries the same canonical inventory and frozen contract', () {
    final report = File(_reportPath).readAsStringSync();
    final inventory = _between(
      report,
      '## 7. Complete Current Inventory',
      '## 8. Reconciliation and Delta from 106AC',
    );
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(inventory).length,
      24,
    );
    for (final id in [..._migrated.keys, ..._remaining.keys]) {
      expect(inventory, contains('| $id |'), reason: id);
    }
    for (final statement in const [
      '24 = 13 + 11',
      '13 legacy `.listProducts(` call sites',
      '13 catalog `.listProductCatalog(` call sites',
      '11 = 6 + 5',
      'FROZEN_TARGET_ID: PRC-103',
      'FROZEN_TARGET_MEMBER: BusinessDataWipeService._currentCounts',
      'FROZEN_INCLUDE_INACTIVE: true',
      'FROZEN_FIELDS: none; List.length only',
      'FROZEN_CONTRACT_EXPANSION: none',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final allowlist = _between(
      report,
      '### Expected production files',
      '### Forbidden production paths',
    );
    final paths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(allowlist)
        .map((match) => match.group(0)!)
        .toSet();
    expect(paths, _expectedProductionFiles);
  });

  test('audit discovery excludes tests, docs, tools, writes, and raw adapters',
      () {
    final sources = _dartSources();
    expect(sources.keys, everyElement(startsWith('lib/')));
    expect(
      _occurrences(sources.values.join('\n'), 'clearForOwnerDataWipe('),
      greaterThan(0),
    );
    expect(
      _remaining.values.any(
        (consumer) =>
            consumer.path == 'lib/core/catalog/drift_product_repository.dart',
      ),
      isTrue,
      reason: 'PRC-118 explicitly classifies the snapshot self-read.',
    );

    final report = File(_reportPath).readAsStringSync();
    expect(
        report, contains('Raw Drift selects are repository implementations'));
    expect(report, contains('write calls are not read consumers'));
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

Map<String, int> _callsByPath(Map<String, _Consumer> consumers) {
  final calls = <String, int>{};
  for (final consumer in consumers.values) {
    calls.update(
      consumer.path,
      (value) => value + consumer.callSites,
      ifAbsent: () => consumer.callSites,
    );
  }
  return calls;
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
