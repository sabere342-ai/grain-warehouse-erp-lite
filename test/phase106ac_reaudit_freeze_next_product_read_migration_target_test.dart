import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '4d4720b2b5c61a0318615691e85ea98f1f1d58af';
const _phaseSubject = 'PHASE 106AC: freeze next product read migration target';
const _reportPath =
    'docs/PHASE-106AC-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath = 'lib/core/backup/backup_restore_service.dart';
const _backupExportPath = 'lib/core/backup/backup_export.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';

const _migrated = <String, _Consumer>{
  'PRC-001':
      _Consumer('lib/core/documents/document_history.dart', 'Accepted', 1),
  'PRC-002':
      _Consumer('lib/features/dashboard/dashboard_screen.dart', 'Accepted', 1),
  'PRC-003': _Consumer(
      'lib/core/inventory/inventory_attention_service.dart', 'Accepted', 1),
  'PRC-004':
      _Consumer('lib/core/dashboard/dashboard_service.dart', 'Accepted', 1),
  'PRC-010': _Consumer(
      'lib/core/inventory/drift_inventory_repository.dart', 'Accepted', 1),
  'PRC-014':
      _Consumer('lib/core/reports/report_repository.dart', 'Accepted', 1),
  'PRC-101': _Consumer('lib/core/backup/backup_export.dart', 'Accepted', 1),
  'PRC-104':
      _Consumer('lib/core/catalog/product_controller.dart', 'Accepted', 1),
  'PRC-107':
      _Consumer('lib/core/inventory/inventory_controller.dart', 'Accepted', 1),
  'PRC-110':
      _Consumer('lib/core/purchases/purchase_controller.dart', 'Accepted', 1),
  'PRC-112': _Consumer('lib/core/sales/sale_controller.dart', 'Accepted', 1),
  'PRC-113': _Consumer(
      'lib/features/financial_reports/profitability_report_screen.dart',
      'Accepted',
      1),
};

const _remaining = <String, _Consumer>{
  'PRC-102': _Consumer('lib/core/backup/backup_restore_service.dart', 'F', 1),
  'PRC-103':
      _Consumer('lib/core/backup/business_data_wipe_service.dart', 'F', 1),
  'PRC-105': _Consumer(
      'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
      'F',
      1),
  'PRC-106':
      _Consumer('lib/core/inventory/drift_inventory_repository.dart', 'F', 1),
  'PRC-108': _Consumer(
      'lib/core/inventory_valuation/profitability_activation_service.dart',
      'F',
      1),
  'PRC-109':
      _Consumer('lib/core/purchases/drift_purchase_repository.dart', 'F', 2),
  'PRC-111': _Consumer('lib/core/sales/sale_repository.dart', 'F', 1),
  'PRC-114': _Consumer('lib/core/inventory/inventory_repository.dart', 'I', 2),
  'PRC-115': _Consumer('lib/core/purchases/purchase_repository.dart', 'I', 1),
  'PRC-116': _Consumer(
      'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
      'I',
      1),
  'PRC-117': _Consumer('lib/app/app_repositories.dart', 'I', 1),
  'PRC-118':
      _Consumer('lib/core/catalog/drift_product_repository.dart', 'I', 1),
};

void main() {
  test('baseline lineage is exact and Phase 106AC has no production diff', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _phaseSubject);
      expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
      expect(_git(['rev-list', '--count', '$_baseline..HEAD']).trim(), '1');
    }
    expect(_git(['diff', _baseline, '--', 'lib']).trim(), isEmpty);
  });

  test('inventory has 24 unique consumers classified exactly once', () {
    expect(_migrated, hasLength(12));
    expect(_remaining, hasLength(12));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
        _migrated.keys.toSet().intersection(_remaining.keys.toSet()), isEmpty);
    expect(_migrated.containsKey('PRC-101'), isTrue);
    expect(_remaining.containsKey('PRC-101'), isFalse);
  });

  test('remaining categories reconcile exactly as F7 and I5', () {
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
      'F': 7,
      'G': 0,
      'H': 0,
      'I': 5,
    });
  });

  test('source call sites reconcile to 14 legacy and 12 catalog calls', () {
    final sources = _dartSources();
    expect(_occurrences(sources.values.join('\n'), '.listProducts('), 14);
    expect(_occurrences(sources.values.join('\n'), '.listProductCatalog('), 12);

    final expectedLegacyFiles = {
      for (final consumer in _remaining.values) consumer.path,
    };
    final actualLegacyFiles = sources.entries
        .where((entry) => entry.value.contains('.listProducts('))
        .map((entry) => entry.key)
        .toSet();
    expect(actualLegacyFiles, expectedLegacyFiles);

    final expectedCatalogFiles = {
      for (final consumer in _migrated.values) consumer.path,
    };
    final actualCatalogFiles = sources.entries
        .where((entry) => entry.value.contains('.listProductCatalog('))
        .map((entry) => entry.key)
        .toSet();
    expect(actualCatalogFiles, expectedCatalogFiles);

    for (final consumer in _remaining.values) {
      expect(_occurrences(sources[consumer.path]!, '.listProducts('),
          consumer.callSites,
          reason: consumer.path);
    }
    for (final consumer in _migrated.values) {
      expect(_occurrences(sources[consumer.path]!, '.listProductCatalog('),
          consumer.callSites,
          reason: consumer.path);
    }
  });

  test('PRC-101 is catalog-only and keeps its eleven-field export', () {
    final source = File(_backupExportPath).readAsStringSync();
    final createBackup =
        _methodBody(source, 'Future<BackupExportResult> createBackup() async');
    expect(
      _compact(createBackup),
      contains(
          '_productCatalogReadRepository.listProductCatalog(includeInactive:true,)'),
    );
    expect(createBackup, isNot(contains('listProducts(')));
    expect(source, isNot(contains('ProductRepository')));
    final mapper = _methodBody(
      source,
      'Map<String, Object?> _productToJson(ProductCatalogReadModel product)',
    );
    expect(RegExp(r"^\s*'([^']+)':", multiLine: true).allMatches(mapper),
        hasLength(11));
  });

  test('PRC-102 is the sole frozen target and its current behavior is exact',
      () {
    const selectedTargets = ['PRC-102'];
    expect(selectedTargets, hasLength(1));
    expect(_remaining['PRC-102']!.classification, 'F');
    final source = File(_targetPath).readAsStringSync();
    final method =
        _methodBody(source, 'Future<String?> _checkEmptySystem() async');
    expect(
      _compact(method),
      contains('_productRepository.listProducts(includeInactive:true)'),
    );
    expect(method, contains('products.isNotEmpty'));
    expect(method, isNot(contains('listProductCatalog(')));
    expect(method, isNot(contains('product.')));

    final restore = _between(
      source,
      'Future<BackupRestoreResult> restoreToEmpty({',
      'Future<String?> _checkEmptySystem() async',
    );
    expect(restore.indexOf('await _checkEmptySystem()'),
        lessThan(restore.indexOf('final snapshots = <SnapshotHolder>[')));
    expect(restore.indexOf('await _checkEmptySystem()'),
        lessThan(restore.indexOf('RepositoryTransaction.execute(')));
  });

  test('current catalog contract fully covers PRC-102 without expansion', () {
    final source = File(_contractPath).readAsStringSync();
    final model = _between(
      source,
      'final class ProductCatalogReadModel {',
      'abstract interface class ProductCatalogReadRepository',
    );
    final fields = RegExp(r'^  final ([^;]+);$', multiLine: true)
        .allMatches(model)
        .map((match) => match.group(1)!)
        .toList(growable: false);
    expect(fields, [
      'String id',
      'String name',
      'String? code',
      'GrainUnit unit',
      'bool isActive',
      'int? referenceCostPricePiastersPerKg',
      'int? defaultSalePricePiastersPerKg',
      'int? minimumSalePricePiastersPerKg',
      'String? notes',
      'DateTime createdAt',
      'DateTime updatedAt',
    ]);
    expect(source, contains('required bool includeInactive'));
  });

  test('report and frozen Phase 106AD scope agree with live source', () {
    final report = File(_reportPath).readAsStringSync();
    expect(_occurrences(report, 'FROZEN_TARGET_ID:'), 1);
    expect(report, contains('FROZEN_TARGET_ID: PRC-102'));
    expect(report, contains('FROZEN_TARGET_CATEGORY: F'));
    expect(report, contains('FROZEN_TARGET_MEMBER: _checkEmptySystem'));
    expect(report, contains('Exactly one consumer migration.'));
    expect(report, contains('Required contract expansion: none'));
    final frozenScope = _between(
      report,
      '## 20. Phase 106AD Exact Scope',
      '## 21. Forbidden Phase 106AD Scope',
    );
    final paths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(frozenScope)
        .map((match) => match.group(0)!)
        .toSet();
    expect(paths, {
      'lib/core/backup/backup_restore_service.dart',
      'lib/app/app_repositories.dart',
    });
  });
}

final class _Consumer {
  const _Consumer(this.path, this.classification, this.callSites);

  final String path;
  final String classification;
  final int callSites;
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll('\\', '/');
    sources[path] = file.readAsStringSync();
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
