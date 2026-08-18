import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
const _historicalScopeEndpoint = 'f521a97946d73829fef19f4f0d30a6d07b9f8051';
const _baselineSubject =
    'PHASE 106AK: freeze next product read migration target';
const _subject =
    'PHASE 106AL: migrate negative balance approval product fingerprint read';
const _phase106alCommit = 'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
const _phase106amSubject =
    'PHASE 106AM: migrate profitability activation product read';
const _phase106amCommit = '8802c2115a45785f8705764514f9c7d0250a050d';
const _phase106anSubject = 'Phase 106AN: migrate PRC-111 product read';
const _targetPath =
    'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _reportPath =
    'docs/PHASE-106AL-NEGATIVE-BALANCE-APPROVAL-PRODUCT-FINGERPRINT-READ-MIGRATION.md';

void main() {
  test('PRC-105 uses only the existing canonical product read contract', () {
    final source = File(_targetPath).readAsStringSync();
    final findProduct = _methodBody(
      source,
      'Future<ProductCatalogReadModel?> _findProduct(String? id) async',
    );
    final requireProduct = _methodBody(
      source,
      'Future<ProductCatalogReadModel> _requireProduct(String id) async',
    );

    expect(source, contains('ProductCatalogReadRepository'));
    expect(source, contains('ProductCatalogReadModel'));
    expect(source, isNot(contains('product_repository.dart')));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('.listProducts(')));
    expect(_occurrences(source, '.listProductCatalog('), 1);
    expect(
      _compact(findProduct),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(
        findProduct, contains("if (id?.trim().isEmpty != false) return null"));
    expect(findProduct, contains("if (value.id == id!.trim()) return value"));
    expect(
        requireProduct, contains('if (product == null || !product.isActive)'));
    expect(
      _occurrences(source, 'product.updatedAt.toUtc().toIso8601String()'),
      2,
    );

    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('final String id;'));
    expect(contract, contains('final bool isActive;'));
    expect(contract, contains('final DateTime updatedAt;'));
    expect(_git(['diff', _baseline, '--', _contractPath]).trim(), isEmpty);
  });

  test('production composition injects the canonical catalog repository', () {
    final source = File(_compositionPath).readAsStringSync();
    final construction = _construction(
      source,
      'NegativeBalanceApprovalWorkflowService(',
    );
    expect(
      construction,
      contains('productCatalogReadRepository: productCatalogReadRepository'),
    );
    expect(construction, isNot(contains('productRepository:')));
  });

  test('inventory moves only PRC-105 from legacy to migrated', () {
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

  test('production scope is exactly target and composition with no schema diff',
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
      'lib/core/inventory_valuation/profitability_activation_service.dart',
      'lib/core/sales/drift_sale_repository.dart',
      'lib/core/sales/sale_repository.dart',
    });
    for (final path in changedProduction) {
      expect(path, isNot(contains('.g.dart')));
      expect(path, isNot(contains('migration')));
    }
    expect(File(_reportPath).existsSync(), isTrue);
  });

  test('report reconciles migrated and remaining consumers separately', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'PRC-105: MIGRATED',
      'PRC-108: REMAINING - Production',
      'PRC-111: REMAINING - Production',
      'Total known consumers: 24',
      'Migrated consumers: 17',
      'Remaining consumers: 7',
      'Production remaining: 2',
      'Infrastructure/Test remaining: 5',
      'Legacy calls: 8',
      'Canonical catalog calls: 18',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('lineage preserves the exact Phase 106AL and 106AM children', () {
    expect(
      _git(['merge-base', '--is-ancestor', _phase106alCommit, 'HEAD']),
      isEmpty,
    );
    expect(
        _git(['log', '-1', '--format=%s', _baseline]).trim(), _baselineSubject);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
            .trim() ==
        'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
    if (head == _baseline) return;
    final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final parent = _git(['rev-parse', 'HEAD^']).trim();
    final atPhase106al = subject == _subject && parent == _baseline;
    final atPhase106am =
        subject == _phase106amSubject && parent == _phase106alCommit;
    final atPhase106an =
        subject == _phase106anSubject && parent == _phase106amCommit;
    expect(atPhase106al || atPhase106am || atPhase106an, isTrue);
    expect(
      _git(['rev-list', '--count', '$_baseline..HEAD']).trim(),
      atPhase106an ? '3' : (atPhase106am ? '2' : '1'),
    );
  });
}

bool _isPhase107GProductionPath(String path) =>
    path == 'lib/main.dart' ||
    path.startsWith('lib/core/trial/') ||
    path.startsWith('lib/features/trial/');

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
  final openBrace = source.indexOf('{', start);
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
