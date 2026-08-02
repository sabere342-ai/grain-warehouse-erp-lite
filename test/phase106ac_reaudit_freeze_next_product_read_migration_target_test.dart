import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _phase106acCommit = '1cd4033720fd765a31b5b5357760c8f55e454f92';
const _phase106adSubject =
    'PHASE 106AD: migrate backup restore empty-system product read';
const _phase106adCommit = 'd7e7dcd21644e2f4946458b4394e94679454c932';
const _phase106aeSubject =
    'PHASE 106AE: freeze next product read migration target';
const _phase106aeCommit = '1d1b24afac39fe3e83704aa73747568c2c9b525c';
const _phase106afSubject =
    'PHASE 106AF: migrate business data wipe current counts product read';
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
  'PRC-102':
      _Consumer('lib/core/backup/backup_restore_service.dart', 'Accepted', 1),
  'PRC-103': _Consumer(
      'lib/core/backup/business_data_wipe_service.dart', 'Accepted', 1),
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
  test('Phase 106AC lineage permits only its frozen Phase 106AD child', () {
    expect(_git(['rev-parse', _phase106acCommit]).trim(), _phase106acCommit);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _phase106acCommit) {
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106ad = subject == _phase106adSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106acCommit;
      final atPhase106ae = subject == _phase106aeSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106adCommit;
      final atPhase106af = subject == _phase106afSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106aeCommit;
      expect(atPhase106ad || atPhase106ae || atPhase106af, isTrue);
      expect(
        _git(['rev-list', '--count', '$_phase106acCommit..HEAD']).trim(),
        atPhase106af ? '3' : (atPhase106ae ? '2' : '1'),
      );
    }
    final productionDiff = _git([
      'diff',
      '--name-only',
      _phase106acCommit,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((path) => path.isNotEmpty).toSet();
    expect(productionDiff, {
      'lib/app/app_repositories.dart',
      'lib/core/backup/backup_restore_service.dart',
      'lib/core/backup/business_data_wipe_service.dart',
    });
  });

  test('inventory has 24 unique consumers classified exactly once', () {
    expect(_migrated, hasLength(14));
    expect(_remaining, hasLength(10));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
        _migrated.keys.toSet().intersection(_remaining.keys.toSet()), isEmpty);
    expect(_migrated.containsKey('PRC-101'), isTrue);
    expect(_remaining.containsKey('PRC-101'), isFalse);
  });

  test('remaining categories reconcile exactly as F5 and I5', () {
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

  test('source call sites reconcile to 12 legacy and 14 catalog calls', () {
    final sources = _dartSources();
    expect(_occurrences(sources.values.join('\n'), '.listProducts('), 12);
    expect(_occurrences(sources.values.join('\n'), '.listProductCatalog('), 14);

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

  test('PRC-102 is the sole migrated target and its behavior is exact', () {
    const selectedTargets = ['PRC-102'];
    expect(selectedTargets, hasLength(1));
    expect(_migrated['PRC-102']!.classification, 'Accepted');
    final source = File(_targetPath).readAsStringSync();
    final method =
        _methodBody(source, 'Future<String?> _checkEmptySystem() async');
    expect(
      _compact(method),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true,)',
      ),
    );
    expect(method, contains('products.isNotEmpty'));
    expect(method, isNot(contains('_productRepository.listProducts(')));
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
