import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '33dccc824014d44265ab606b9f7d6a01713139e3';
const _phaseSubject = 'PHASE 106AA: freeze next product read migration target';
const _reportPath =
    'docs/PHASE-106AA-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath = 'lib/core/backup/backup_export.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

const _migratedConsumerFiles = {
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _remaining = <String, String>{
  'PRC-101': 'D',
  'PRC-102': 'F',
  'PRC-103': 'F',
  'PRC-105': 'F',
  'PRC-106': 'F',
  'PRC-108': 'F',
  'PRC-109': 'F',
  'PRC-111': 'F',
  'PRC-114': 'I',
  'PRC-115': 'I',
  'PRC-116': 'I',
  'PRC-117': 'I',
  'PRC-118': 'I',
};

void main() {
  test('lineage is the exact Phase 106Z baseline or its Phase 106AA child', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      expect(_git(['log', '-1', '--format=%s', 'HEAD']).trim(), _phaseSubject);
      expect(_git(['rev-parse', 'HEAD^']).trim(), _baseline);
    }
    expect(_git(['diff', _baseline, 'HEAD', '--', 'lib']).trim(), isEmpty);
  });

  test('direct calls reconcile to 15 legacy and 11 catalog calls', () {
    expect(_sourceOccurrenceCount('.listProducts('), 15);
    expect(_sourceOccurrenceCount('.listProductCatalog('), 11);
    expect(_sourceFilesWith('.listProductCatalog('), _migratedConsumerFiles);
    expect(_sourceFilesWith('.listProducts('), hasLength(13));
  });

  test('24 consumers reconcile as 11 migrated plus 13 remaining', () {
    expect(_migratedConsumerFiles, hasLength(11));
    expect(_remaining, hasLength(13));
    expect(_migratedConsumerFiles.length + _remaining.length, 24);
    expect(_remaining.keys, contains('PRC-101'));
    expect(_remaining.keys, isNot(contains('PRC-113')));
  });

  test('remaining categories reconcile exactly as D1 F7 I5', () {
    final counts = <String, int>{
      for (final category in 'ABCDEFGHI'.split('')) category: 0,
    };
    for (final category in _remaining.values) {
      counts[category] = counts[category]! + 1;
    }
    expect(counts, {
      'A': 0,
      'B': 0,
      'C': 0,
      'D': 1,
      'E': 0,
      'F': 7,
      'G': 0,
      'H': 0,
      'I': 5,
    });
  });

  test('PRC-101 remains on its exact legacy dependency and call in 106AA', () {
    final source = File(_targetPath).readAsStringSync();
    final constructor = _between(
      source,
      'class BackupExportService {',
      'static const int backupVersion',
    );
    final createBackup =
        _methodBody(source, 'Future<BackupExportResult> createBackup() async');
    expect(
        constructor, contains('required ProductRepository productRepository'));
    expect(source, contains('final ProductRepository _productRepository;'));
    expect(
      _compact(createBackup),
      contains('_productRepository.listProducts(includeInactive:true,)'),
    );
    expect(createBackup, isNot(contains('listProductCatalog(')));
    expect(source, isNot(contains('ProductCatalogReadRepository')));
  });

  test('PRC-101 serialization freezes all 11 fields and timestamp behavior',
      () {
    final source = File(_targetPath).readAsStringSync();
    final mapper = _methodBody(
      source,
      'Map<String, Object?> _productToJson(Product product)',
    );
    final keys = RegExp(r"^\s*'([^']+)':", multiLine: true)
        .allMatches(mapper)
        .map((match) => match.group(1)!)
        .toList(growable: false);
    expect(keys, [
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
    ]);
    expect(mapper, contains('product.unit.name'));
    expect(mapper, contains('product.createdAt.toUtc().toIso8601String()'));
    expect(mapper, contains('product.updatedAt.toUtc().toIso8601String()'));
    expect(_occurrences(mapper, '??'), 0);
    expect(_occurrences(mapper, '.trim()'), 0);
  });

  test('current catalog contract is unchanged and lacks only timestamps', () {
    final contract = File(_contractPath).readAsStringSync();
    final model = _between(
      contract,
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
    ]);
    expect(model, isNot(contains('createdAt')));
    expect(model, isNot(contains('updatedAt')));
    final adapter = File(_adapterPath).readAsStringSync();
    expect(adapter, isNot(contains('createdAt:')));
    expect(adapter, isNot(contains('updatedAt:')));
  });

  test('report freezes exactly one target and the exact Phase 106AB delta', () {
    final report = File(_reportPath).readAsStringSync();
    expect(_occurrences(report, 'FROZEN_TARGET_ID:'), 1);
    expect(report, contains('FROZEN_TARGET_ID: PRC-101'));
    expect(
      report,
      contains('FROZEN_TARGET_MEMBER: '
          'Future<BackupExportResult> createBackup() async'),
    );
    expect(report, contains('FROZEN_TARGET_CATEGORY: D'));
    expect(report, contains('DateTime createdAt'));
    expect(report, contains('DateTime updatedAt'));
    expect(
      report,
      contains('_productCatalogReadRepository.listProductCatalog('
          'includeInactive: true)'),
    );
    expect(report, contains('exactly two required non-null fields'));
  });

  test('next phase production allowlist is closed to exactly four files', () {
    final report = File(_reportPath).readAsStringSync();
    final section = _between(
      report,
      '## 18. Expected Production Diff',
      '## 19. Explicit Exclusions',
    );
    final paths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(section)
        .map((match) => match.group(0)!)
        .toSet();
    expect(paths, {
      'lib/core/catalog/product_catalog_read_repository.dart',
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
      'lib/core/backup/backup_export.dart',
      'lib/app/app_repositories.dart',
    });
  });

  test('report inventory and arithmetic are canonical and complete', () {
    final report = File(_reportPath).readAsStringSync();
    final inventory = _between(
      report,
      '## 7. Complete Consumer Inventory',
      '## 8. Call-site Reconciliation',
    );
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(inventory).length,
      24,
    );
    for (final statement in const [
      '24 = 11 + 13',
      '15 legacy .listProducts(...) calls',
      '11 catalog .listProductCatalog(...) calls',
      '13 = 0 + 0 + 0 + 1 + 0 + 7 + 0 + 0 + 5',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('schema, migrations, generated files, and all production stay frozen',
      () {
    for (final path in const [
      'lib/core/persistence',
      'lib/core/catalog/product_catalog_read_repository.dart',
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
      _targetPath,
      'lib/app/app_repositories.dart',
    ]) {
      expect(_git(['diff', _baseline, 'HEAD', '--', path]).trim(), isEmpty,
          reason: path);
    }
  });
}

Set<String> _sourceFilesWith(String pattern) => Directory('lib')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => file.readAsStringSync().contains(pattern))
    .map((file) => _relative(file.path))
    .toSet();

int _sourceOccurrenceCount(String pattern) => Directory('lib')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => _occurrences(file.readAsStringSync(), pattern))
    .fold(0, (sum, count) => sum + count);

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

String _relative(String path) {
  final normalized = path.replaceAll('\\', '/');
  final root = Directory.current.path.replaceAll('\\', '/');
  return normalized.replaceFirst('$root/', '');
}
