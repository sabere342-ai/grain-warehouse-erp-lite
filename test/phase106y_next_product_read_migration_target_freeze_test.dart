import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '30021696ab2667340e032832892d3c2ecc5dadd7';
const _phase106yCommit = 'fe549ecde9eba4de9c3d4916f611eae8fb58720e';
const _phaseSubject = 'PHASE 106Y: freeze next product read migration target';
const _phase106zSubject =
    'PHASE 106Z: migrate profitability report activation product read';
const _phase106zCommit = '33dccc824014d44265ab606b9f7d6a01713139e3';
const _phase106aaSubject =
    'PHASE 106AA: freeze next product read migration target';
const _phase106aaCommit = '6c04de68e38dcc499f704970e9c00b01fbccf0f1';
const _phase106abSubject =
    'PHASE 106AB: extend product catalog timestamps and migrate backup export';
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
const _reportPath =
    'docs/PHASE-106Y-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath =
    'lib/features/financial_reports/profitability_report_screen.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

const _legacyConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/purchases/purchase_repository.dart',
  'lib/core/sales/sale_repository.dart',
  _targetPath,
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
};

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
};

const _remainingUnits = <_InventoryUnit>[
  _InventoryUnit('PRC-101', 'I', 'lib/core/backup/backup_export.dart',
      'Future<BackupExportResult> createBackup() async', 1),
  _InventoryUnit('PRC-102', 'E', 'lib/core/backup/backup_restore_service.dart',
      'Future<String?> _checkEmptySystem() async', 1),
  _InventoryUnit(
      'PRC-103',
      'E',
      'lib/core/backup/business_data_wipe_service.dart',
      'Future<BusinessDataWipeCounts> _currentCounts() async',
      1),
  _InventoryUnit(
      'PRC-105',
      'E',
      'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
      'Future<Product?> _findProduct(String? id) async',
      1),
  _InventoryUnit(
      'PRC-106',
      'E',
      'lib/core/inventory/drift_inventory_repository.dart',
      'Future<Product?> _findProductById(String id) async',
      1),
  _InventoryUnit(
      'PRC-108',
      'E',
      'lib/core/inventory_valuation/profitability_activation_service.dart',
      'Future<void> activate({',
      1),
  _InventoryUnit(
      'PRC-109',
      'E',
      'lib/core/purchases/drift_purchase_repository.dart',
      'Future<Product> _validateProduct(String id) async',
      2),
  _InventoryUnit('PRC-111', 'E', 'lib/core/sales/sale_repository.dart',
      'Future<Product> _validateProduct(String productId) async', 1),
  _InventoryUnit('PRC-113', 'E', _targetPath,
      'Future<void> _activate(AppUser user) async', 1),
  _InventoryUnit('PRC-114', 'H', 'lib/core/inventory/inventory_repository.dart',
      'Future<Map<String, int>> allProductBalancesKg({', 2),
  _InventoryUnit('PRC-115', 'H', 'lib/core/purchases/purchase_repository.dart',
      'Future<Product> _validateProduct(String productId) async', 1),
  _InventoryUnit(
      'PRC-116',
      'H',
      'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
      'Future<SyntheticActivationResult> activate({',
      1),
  _InventoryUnit('PRC-117', 'G', 'lib/app/app_repositories.dart',
      'final class _LegacyProductCatalogReadRepository', 1),
  _InventoryUnit(
      'PRC-118',
      'G',
      'lib/core/catalog/drift_product_repository.dart',
      'class _DriftProductSnapshot extends SnapshotHolder',
      1),
];

const _readModelFields = [
  'String id',
  'String name',
  'String? code',
  'GrainUnit unit',
  'bool isActive',
  'int? referenceCostPricePiastersPerKg',
  'int? defaultSalePricePiastersPerKg',
  'int? minimumSalePricePiastersPerKg',
  'String? notes',
];

void main() {
  test('baseline, single phase child, and production no-diff are guarded', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atPhase106y = head == _phase106yCommit &&
        subject == _phaseSubject &&
        _git(['rev-parse', '$head^']).trim() == _baseline;
    final afterPhase106z = subject == _phase106zSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106yCommit;
    final afterPhase106aa = subject == _phase106aaSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106zCommit;
    final afterPhase106ab = subject == _phase106abSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106aaCommit;
    final atPhase106ac = head == _phase106acCommit;
    final afterPhase106ad = subject == _phase106adSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106acCommit;
    final afterPhase106ae = subject == _phase106aeSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106adCommit;
    final afterPhase106af = subject == _phase106afSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106aeCommit;
    final afterPhase106ag = subject == _phase106agSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106afCommit;
    final validHead = head == _baseline ||
        atPhase106y ||
        afterPhase106z ||
        afterPhase106aa ||
        afterPhase106ab ||
        atPhase106ac ||
        afterPhase106ad ||
        afterPhase106ae ||
        afterPhase106af ||
        afterPhase106ag;
    expect(validHead, isTrue,
        reason: 'Only the exact 106X baseline, Phase 106Y, or its single Phase '
            '106Z, Phase 106AA, or Phase 106AB child is valid.');
    final productionDiff =
        _git(['diff', '--name-only', _phase106yCommit, 'HEAD', '--', 'lib'])
            .split(RegExp(r'\r?\n'))
            .where((path) => path.isNotEmpty)
            .toSet();
    expect(
      productionDiff,
      (afterPhase106af || afterPhase106ag)
          ? {
              _targetPath,
              'lib/app/app_repositories.dart',
              'lib/core/backup/backup_export.dart',
              'lib/core/backup/backup_restore_service.dart',
              'lib/core/backup/business_data_wipe_service.dart',
              'lib/core/catalog/drift_product_catalog_read_repository.dart',
              'lib/core/catalog/product_catalog_read_repository.dart',
            }
          : (afterPhase106ad || afterPhase106ae)
              ? {
                  _targetPath,
                  'lib/app/app_repositories.dart',
                  'lib/core/backup/backup_export.dart',
                  'lib/core/backup/backup_restore_service.dart',
                  'lib/core/catalog/drift_product_catalog_read_repository.dart',
                  'lib/core/catalog/product_catalog_read_repository.dart',
                }
              : (afterPhase106ab || atPhase106ac)
                  ? {
                      _targetPath,
                      'lib/app/app_repositories.dart',
                      'lib/core/backup/backup_export.dart',
                      'lib/core/catalog/drift_product_catalog_read_repository.dart',
                      'lib/core/catalog/product_catalog_read_repository.dart',
                    }
                  : (afterPhase106z || afterPhase106aa)
                      ? {_targetPath}
                      : isEmpty,
      reason: 'Only the frozen Phase 106Z target and Phase 106AB allowlist '
          'may appear in the forward production lineage.',
    );
  });

  test('all direct legacy and catalog calls reconcile from current source', () {
    expect(_sourceOccurrenceCount('.listProducts('), 16);
    expect(_sourceOccurrenceCount('.listProductCatalog('), 10);

    final legacyFiles = _sourceFilesWith('.listProducts(');
    expect(legacyFiles.difference(_legacyInfrastructureFiles),
        _legacyConsumerFiles);
    expect(legacyFiles.intersection(_legacyInfrastructureFiles),
        _legacyInfrastructureFiles);
    expect(legacyFiles, hasLength(14));
    expect(_sourceFilesWith('.listProductCatalog('), _migratedConsumerFiles);
  });

  test('24 logical units reconcile as 10 migrated plus 14 remaining', () {
    expect(_migratedConsumerFiles, hasLength(10));
    expect(_remainingUnits, hasLength(14));
    expect(_migratedConsumerFiles.length + _remainingUnits.length, 24);
    expect(_remainingUnits.map((unit) => unit.id).toSet(), hasLength(14));
    expect(_remainingUnits.where((unit) => unit.id == 'PRC-104'), isEmpty,
        reason: 'ProductController moved to the migrated set in Phase 106X.');
  });

  test('each remaining unit is anchored to its current source and call count',
      () {
    for (final unit in _remainingUnits) {
      final source = _phaseSource(unit.file);
      expect(source, contains(unit.member), reason: unit.id);
      expect(_occurrences(source, '.listProducts('), unit.fileCallCount,
          reason: '${unit.id}: ${unit.file}');
    }
    expect(
        _remainingUnits.fold<int>(0, (sum, unit) {
          // PRC-106 shares a file with one catalog call but owns one legacy call.
          // No two remaining units share a legacy file, so file counts sum safely.
          return sum + unit.fileCallCount;
        }),
        16);
  });

  test('A-I classification covers the remaining inventory exactly once', () {
    final counts = <String, int>{
      for (final key in 'ABCDEFGHI'.split('')) key: 0
    };
    for (final unit in _remainingUnits) {
      counts[unit.category] = counts[unit.category]! + 1;
    }
    expect(counts, {
      'A': 0,
      'B': 0,
      'C': 0,
      'D': 0,
      'E': 8,
      'F': 0,
      'G': 2,
      'H': 3,
      'I': 1,
    });
  });

  test('Phase 106X ProductController stays migrated while writes stay legacy',
      () {
    final source = _phaseSource('lib/core/catalog/product_controller.dart');
    final load = _between(source, 'Future<void> loadProducts(AppUser user)',
        'Future<bool> createProduct(');
    final compact = _compact(load);
    expect(
        compact, contains('_productCatalogReadRepository.listProductCatalog('));
    expect(compact,
        contains('includeInactive:user.permissions.canManageProducts'));
    expect(load, isNot(contains('listProducts(')));
    expect(source, contains('final ProductRepository _repository;'));
    for (final write in [
      '_repository.createProduct(',
      '_repository.updateProduct(',
      '_repository.setProductActive(',
    ]) {
      expect(source, contains(write), reason: write);
    }
  });

  test('catalog contract remains exactly nine fields including nullable notes',
      () {
    final source = _phaseSource(_contractPath);
    final model = _between(source, 'final class ProductCatalogReadModel {',
        'abstract interface class ProductCatalogReadRepository');
    final fields = RegExp(r'^  final ([^;]+);$', multiLine: true)
        .allMatches(model)
        .map((match) => match.group(1)!)
        .toList(growable: false);
    expect(fields, _readModelFields);
    expect(model, contains('required this.notes'));
  });

  test('Drift adapter preserves filter, order, nulls, and notes without N+1',
      () {
    final source = _phaseSource(_adapterPath);
    expect(_occurrences(source, 'await query.get()'), 1);
    expect(source, contains('query.where(products.isActive.equals(true))'));
    expect(source, contains('OrderingTerm.asc(products.createdAt)'));
    expect(source, contains('OrderingTerm.asc(products.id)'));
    expect(source, contains('code: row.read(products.code)'));
    expect(source, contains('notes: row.read(products.notes)'));
    expect(source, isNot(contains('.trim()')));
    expect(source, isNot(contains('notes ??')));
    expect(source, isNot(contains('listProducts(')));
  });

  test('PRC-113 current read path and includeInactive behavior are exact', () {
    final source = _phaseSource(_targetPath);
    final activate =
        _methodBody(source, 'Future<void> _activate(AppUser user) async');
    final compact = _compact(activate);
    expect(
        compact,
        contains(
            'AppRepositories.productRepository.listProducts(includeInactive:true)'));
    expect(_occurrences(activate, '.listProducts('), 1);
    expect(activate, isNot(contains('.listProductCatalog(')));
    expect(source, contains("core/catalog/product.dart"));
    expect(source, contains('final List<Product> products;'));
  });

  test('PRC-113 consumes exactly id and name from each product', () {
    final source = _phaseSource(_targetPath);
    final dialog = _between(
        source,
        'class _ActivationDialog extends StatefulWidget',
        'class _ActivationInput {');
    final productFields = RegExp(r'product\.(\w+)')
        .allMatches(dialog)
        .map((match) => match.group(1)!)
        .toSet();
    expect(productFields, {'id', 'name'});
  });

  test('PRC-113 is genuinely production reachable through financial reports',
      () {
    final shell = _phaseSource('lib/features/dashboard/dashboard_shell.dart');
    final reports = _phaseSource(
        'lib/features/financial_reports/financial_reports_screen.dart');
    expect(shell, contains('FinancialReportsScreen()'));
    expect(reports, contains('const ProfitabilityReportScreen()'));
    expect(reports, contains('canViewFinancialReports'));
    expect(_phaseSource(_targetPath),
        contains('AppRepositories.profitabilityActivationService.activate('));
  });

  test('PRC-113 is the sole frozen target and is not migrated in 106Y', () {
    final report = _phaseSource(_reportPath);
    expect(_occurrences(report, 'FROZEN_TARGET_ID: PRC-113'), 1);
    expect(_occurrences(report, 'FROZEN_TARGET_ID:'), 1);
    expect(
        report,
        contains(
            'FROZEN_TARGET_MEMBER: _ProfitabilityReportScreenState._activate(AppUser user)'));
    expect(report, contains('FROZEN_TARGET_CATEGORY: E'));
    expect(_phaseSource(_targetPath), isNot(contains('.listProductCatalog(')));
  });

  test('next phase has one production file and requires no contract expansion',
      () {
    final report = _phaseSource(_reportPath);
    final plan = _between(report, '## 11. Frozen Phase 106Z plan',
        '## 12. Phase 106Y guard scope');
    final allowlist =
        _between(plan, 'Closed production allowlist:', 'Implementation plan:');
    final productionPaths = RegExp(r'^- `(lib/[^`]+)`$', multiLine: true)
        .allMatches(allowlist)
        .map((match) => match.group(1)!)
        .toSet();
    expect(productionPaths, {_targetPath});
    expect(plan, contains('Contract expansion: **no**'));
    expect(plan, contains('New fields: **none**'));
    expect(plan, contains('exactly PRC-113 moves'));
    expect(plan,
        contains('PRC-108 and all other remaining legacy units are unchanged'));
  });

  test('report inventory rows, counts, and reconciliation are internally exact',
      () {
    final report = _phaseSource(_reportPath);
    final rows =
        RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length;
    expect(rows, 14);
    for (final statement in const [
      'Total identified logical units | 24',
      'Migrated and accepted units | 10',
      'Remaining classified units | 14',
      'Legacy `.listProducts(` call sites in `lib/` | 16',
      'Catalog `.listProductCatalog(` call sites in `lib/` | 10',
      '`24 = 10 + 14`',
      '`0 + 0 + 0 + 0 + 8 + 0 + 2 + 3 + 1 = 14`',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('backup and transaction alternatives are explicitly kept out of scope',
      () {
    final report = _phaseSource(_reportPath);
    for (final statement in const [
      'full-fidelity archival/restore shape is a separate architectural boundary',
      'PRC-108 service migration',
      'do not construct `Product` from the read model',
      'do not migrate PRC-113 or any other consumer',
      'No migration, schema, generated, Push, or Tag action was performed.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('schema, migrations, and generated persistence remain at 106X baseline',
      () {
    expect(
      _git(['diff', _baseline, 'HEAD', '--', 'lib/core/persistence']).trim(),
      isEmpty,
    );
    expect(
      _git(['diff', _baseline, _phase106yCommit, '--', 'lib']).trim(),
      isEmpty,
    );
  });

  test('Phase 105 and 106 product-catalog timeline remains linear', () {
    for (final commit in const [
      'e0b0424', // 105B contract
      'edda4ec', // 105C adapter
      'ea804cb', // 105D first migration
      '6d27467', // 105E runtime proof
      'a813a70', // 105F acceptance
      '2b90ca0', // 106V sale runtime proof
      'b7d5086', // 106W target freeze
      _baseline, // 106X ProductController migration
    ]) {
      expect(_isAncestor(commit, 'HEAD'), isTrue, reason: commit);
    }
    expect(
      _git(['log', '-1', '--format=%s', _baseline]).trim(),
      'PHASE 106X: extend product catalog notes and migrate product controller',
    );
  });
}

final class _InventoryUnit {
  const _InventoryUnit(
      this.id, this.category, this.file, this.member, this.fileCallCount);

  final String id;
  final String category;
  final String file;
  final String member;
  final int fileCallCount;
}

Set<String> _sourceFilesWith(String pattern) => _git([
      'grep',
      '-l',
      '-F',
      pattern,
      _phase106yCommit,
      '--',
      'lib',
    ])
        .split(RegExp(r'\r?\n'))
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst('$_phase106yCommit:', ''))
        .where((path) => path.endsWith('.dart'))
        .toSet();

int _sourceOccurrenceCount(String pattern) => _sourceFilesWith(pattern)
    .map((path) => _occurrences(_phaseSource(path), pattern))
    .fold(0, (sum, count) => sum + count);

String _phaseSource(String path) => _git(['show', '$_phase106yCommit:$path']);

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

bool _isAncestor(String ancestor, String descendant) =>
    Process.runSync(
      'git',
      ['merge-base', '--is-ancestor', ancestor, descendant],
      runInShell: false,
    ).exitCode ==
    0;

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
