import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '33dccc824014d44265ab606b9f7d6a01713139e3';
const _phaseSubject = 'PHASE 106AA: freeze next product read migration target';
const _phase106aaCommit = '6c04de68e38dcc499f704970e9c00b01fbccf0f1';
const _phase106abSubject =
    'PHASE 106AB: extend product catalog timestamps and migrate backup export';
const _phase106abCommit = '4d4720b2b5c61a0318615691e85ea98f1f1d58af';
const _phase106acSubject =
    'PHASE 106AC: freeze next product read migration target';
const _phase106acCommit = '1cd4033720fd765a31b5b5357760c8f55e454f92';
const _phase106adSubject =
    'PHASE 106AD: migrate backup restore empty-system product read';
const _phase106adCommit = 'd7e7dcd21644e2f4946458b4394e94679454c932';
const _phase106aeSubject =
    'PHASE 106AE: freeze next product read migration target';
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
  test('lineage preserves Phase 106AA through its Phase 106AD child', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106aa = subject == _phaseSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _baseline;
      final atPhase106ab = subject == _phase106abSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106aaCommit;
      final atPhase106ac = subject == _phase106acSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106abCommit;
      final atPhase106ad = subject == _phase106adSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106acCommit;
      final atPhase106ae = subject == _phase106aeSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106adCommit;
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
      expect(
        atPhase106aa ||
            atPhase106ab ||
            atPhase106ac ||
            atPhase106ad ||
            atPhase106ae ||
            atPhase106af ||
            atPhase106ag ||
            atPhase106ah ||
            atPhase106ai ||
            atPhase106aj ||
            atPhase106ak ||
            atPhase106al ||
            atPhase106am,
        isTrue,
      );
    }
    expect(_git(['diff', _baseline, _phase106aaCommit, '--', 'lib']).trim(),
        isEmpty);
    final forwardDiff = _git(
      ['diff', '--name-only', _phase106aaCommit, '--', 'lib'],
    ).split(RegExp(r'\r?\n')).where((path) => path.isNotEmpty).toSet();
    expect(
      forwardDiff,
      anyOf(
        isEmpty,
        _phase106abProductionFiles,
        _phase106adCumulativeProductionFiles,
        _phase106afCumulativeProductionFiles,
        _phase106alCumulativeProductionFiles,
      ),
    );
  });

  test('direct calls reconcile to 15 legacy and 11 catalog calls', () {
    expect(_sourceOccurrenceCountAt(_phase106aaCommit, '.listProducts('), 15);
    expect(_sourceOccurrenceCountAt(_phase106aaCommit, '.listProductCatalog('),
        11);
    expect(_sourceFilesWithAt(_phase106aaCommit, '.listProductCatalog('),
        _migratedConsumerFiles);
    expect(
        _sourceFilesWithAt(_phase106aaCommit, '.listProducts('), hasLength(13));
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
    final source = _sourceAt(_phase106aaCommit, _targetPath);
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
    final source = _sourceAt(_phase106aaCommit, _targetPath);
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
    final contract = _sourceAt(_phase106aaCommit, _contractPath);
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
    final adapter = _sourceAt(_phase106aaCommit, _adapterPath);
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
      expect(_git(['diff', _baseline, _phase106aaCommit, '--', path]).trim(),
          isEmpty,
          reason: path);
    }
  });
}

const _phase106abProductionFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/backup/backup_export.dart',
  'lib/core/catalog/drift_product_catalog_read_repository.dart',
  'lib/core/catalog/product_catalog_read_repository.dart',
};

const _phase106adCumulativeProductionFiles = {
  ..._phase106abProductionFiles,
  'lib/core/backup/backup_restore_service.dart',
};

const _phase106afCumulativeProductionFiles = {
  ..._phase106adCumulativeProductionFiles,
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
};

const _phase106alCumulativeProductionFiles = {
  ..._phase106afCumulativeProductionFiles,
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
};

Set<String> _sourceFilesWithAt(String revision, String pattern) =>
    _git(['grep', '-l', '-F', pattern, revision, '--', 'lib'])
        .split(RegExp(r'\r?\n'))
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst('$revision:', ''))
        .toSet();

int _sourceOccurrenceCountAt(String revision, String pattern) => _git([
      'grep',
      '-o',
      '-F',
      pattern,
      revision,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((line) => line.isNotEmpty).length;

String _sourceAt(String revision, String path) =>
    _git(['show', '$revision:$path']);

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
