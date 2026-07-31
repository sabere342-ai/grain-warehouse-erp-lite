import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '80ede9595b51c17d1b82f16a9198b91a9d9422d9';
const _phase106pBaseline = '4b7b1f2b2c32675a5c0f3aa0f96ef1227e7dd7b0';
const _phase106qCommit = 'f0341e9e070012953bce487c20401bf36eec1b87';
const _phase106rCommit = 'ad03bd0b27109ac2ec97d80ffa32fca22d0f41d9';
const _phase106rSubject =
    'PHASE 106R: migrate inventory controller product catalog read';
const _phase106sSubject =
    'PHASE 106S: prove runtime inventory controller product catalog '
    'integration';
const _reportPath =
    'docs/PHASE-106Q-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath = 'lib/core/inventory/inventory_controller.dart';
const _inventoryScreenPath = 'lib/features/inventory/inventory_screen.dart';
const _stockTakeScreenPath = 'lib/features/inventory/stock_take_screen.dart';
const _stockAdjustmentScreenPath =
    'lib/features/inventory/stock_adjustment_report_screen.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';
const _purchaseControllerPath = 'lib/core/purchases/purchase_controller.dart';

const _legacyConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/purchases/purchase_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
};

const _migratedConsumerFiles = {
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/reports/report_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

const _frozenReadModelFields = {
  'id',
  'name',
  'code',
  'unit',
  'isActive',
  'referenceCostPricePiastersPerKg',
};

void main() {
  test('baseline lineage: Phase 106Q starts from the single Phase 106P commit',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(_git(['rev-parse', '$_baseline^']).trim(), _phase106pBaseline);

    final head = _git(['rev-parse', 'HEAD']).trim();
    final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atBaseline = head == _baseline;
    final afterFreeze = headSubject ==
            'PHASE 106Q: freeze next product read migration target' &&
        _git(['rev-parse', '$head^']).trim() == _baseline;
    final afterMigration = headSubject == _phase106rSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106qCommit;
    final afterProve = headSubject == _phase106sSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106rCommit;
    expect(atBaseline || afterFreeze || afterMigration || afterProve, isTrue,
        reason:
            'HEAD must be the 106P baseline (during development), the single '
            'Phase 106Q freeze commit, the single Phase 106R migration commit '
            'whose parent is exactly the 106Q commit, or the single Phase '
            '106S proof commit whose parent is exactly the 106R commit.');

    final commitCount =
        int.parse(_git(['rev-list', '--count', '$_baseline..HEAD']).trim());
    expect(commitCount >= 0 && commitCount <= 3, isTrue,
        reason: 'Zero, one, two, or three commits may exist after the 106P '
            'baseline; an open number of commits must fail loudly.');
  });

  test('Phase 106Q is discovery/freeze only: no production diff', () {
    expect(
        _git([
          'diff',
          '--name-only',
          _baseline,
          _phase106qCommit,
          '--',
          'lib',
        ]).trim(),
        isEmpty,
        reason: 'No production file under lib/ may differ from the 106P '
            'baseline at the 106Q commit.');
    final worktree = _git(['diff', '--name-only', '--', 'lib'])
        .trim()
        .split(RegExp(r'\r?\n'))
        .where((path) => path.trim().isNotEmpty)
        .toSet();
    expect(
      worktree.difference(const {
        'lib/core/inventory/inventory_controller.dart',
        'lib/features/inventory/inventory_screen.dart',
        'lib/features/inventory/stock_take_screen.dart',
        'lib/features/inventory/stock_adjustment_report_screen.dart',
      }),
      isEmpty,
      reason: 'Any working-tree lib/ diff must be limited to the Phase 106R '
          'migration files.',
    );
    final check = Process.runSync(
      'git',
      ['diff', '--check'],
      runInShell: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    expect(check.exitCode, 0, reason: 'git diff --check must pass.');
  });

  test('reconciliation: total equals migrated plus remaining (24 = 7 + 17)',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Remaining inventory: 17',
      'Migrated and accepted: 7',
      'Total identified: 24',
      '`24 = 7 + 17` — exact match',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final legacyFiles = _gitGrepFiles('.listProducts(', _baseline)
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _gitGrepFiles('.listProductCatalog(', _baseline);
    expect(legacyFiles, _legacyConsumerFiles,
        reason:
            'Exactly the 15 legacy consumer files must still call .listProducts(.');
    expect(migratedFiles, _migratedConsumerFiles,
        reason:
            'Exactly the 7 migrated consumer files must call .listProductCatalog(.');
  });

  test('all seven accepted consumers remain on the catalog boundary', () {
    for (final path in _migratedConsumerFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('.listProductCatalog('), reason: path);
    }
    for (final path in const [
      'lib/core/dashboard/dashboard_service.dart',
      'lib/core/documents/document_history.dart',
      'lib/core/inventory/inventory_attention_service.dart',
      'lib/core/purchases/purchase_controller.dart',
      'lib/core/reports/report_repository.dart',
      'lib/features/dashboard/dashboard_screen.dart',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('.listProducts(')),
          reason: path);
    }
  });

  test('classification: every remaining consumer has exactly one A-I class',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final total in const [
      'A — Read-Only, Current-Contract Fit, Standalone: 0',
      'B — Current-Contract Fit (broader context): 1',
      'C — Requires a Broader Read Contract: 2',
      'D — Requires a Single-Item Lookup: 0',
      'E — Requires a Stream / Reactive Read: 0',
      'F — Write-Coupled / Transaction-Integrity Read: 8',
      'G — Financial / Inventory / Accounting Criticality: 1',
      'H — Not Production-Reachable: 3',
      'I — False Positive (Infrastructure): 2',
      'Sum of categories: 17',
      'Remaining inventory: 17',
      'Migrated and accepted: 7',
      'Total identified: 24',
    ]) {
      expect(report, contains(total), reason: total);
    }
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length,
      17,
      reason: 'The 106Q report must inventory exactly the 17 remaining rows.',
    );
  });

  test('InventoryController.load is the single selected migration target', () {
    final report = File(_reportPath).readAsStringSync();
    final selections = RegExp(
      r'^Selected migration target:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['InventoryController.load']);
    expect(report, contains('Classification: B'));
    expect(
      report,
      contains(
          'Phase 106R — Migrate `InventoryController.load` to `ProductCatalogReadRepository`'),
    );
    expect(
      RegExp(r'^\| (PRC-\d{3}) \|.*\*\*B — selected\*\*', multiLine: true)
          .allMatches(report)
          .map((match) => match.group(1)!)
          .toList(),
      ['PRC-107'],
    );
  });

  test('selected target is read-only, production reachable, still legacy', () {
    final controller = _git(['show', '$_baseline:$_targetPath']);
    final classStart = controller.indexOf('class InventoryController');
    final methodStart =
        controller.indexOf('Future<void> load(AppUser user)', classStart);
    final asyncStart = controller.indexOf(' async {', methodStart);
    final body = _bracedBody(controller, asyncStart);

    expect(
        controller, contains('required ProductRepository productRepository'));
    expect(_occurrences(body, '_productRepository.listProducts('), 1);
    expect(body, contains('includeInactive: user.permissions'));
    expect(body, isNot(contains('.listProductCatalog(')));
    expect(body, isNot(contains('_productCatalogReadRepository')));
    for (final forbidden in const [
      '.transaction(',
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'restoreProductsIntoEmpty(',
      'clearForOwnerDataWipe(',
      '_inventoryRepository.createMovement(',
      'createOpeningBalance(',
      'createManualIncrease(',
      'createManualDecrease(',
    ]) {
      expect(body, isNot(contains(forbidden)), reason: forbidden);
    }

    for (final path in const [
      _inventoryScreenPath,
      _stockTakeScreenPath,
      _stockAdjustmentScreenPath,
    ]) {
      final screen = File(path).readAsStringSync();
      expect(screen, contains('InventoryController('));
      expect(
        screen,
        matches(RegExp(r'AppRepositories\.(productRepository|'
            r'productCatalogReadRepository)')),
        reason: path,
      );
    }
  });

  test('selected target needs exactly id and name', () {
    final controller = _git(['show', '$_baseline:$_targetPath']);
    final inventory = File(_inventoryScreenPath).readAsStringSync();
    final stockTake = File(_stockTakeScreenPath).readAsStringSync();
    final adjustment = File(_stockAdjustmentScreenPath).readAsStringSync();
    final consumerSource = '$controller\n$inventory\n$stockTake\n$adjustment';

    for (final field in const ['product.id', 'product.name']) {
      expect(consumerSource, contains(field), reason: field);
    }
    for (final forbidden in const [
      'defaultSalePricePiastersPerKg',
      'minimumSalePricePiastersPerKg',
      'product.code',
      'product.unit',
      'product.isActive',
      'product.notes',
      'product.createdAt',
      'product.updatedAt',
      'referenceCostPricePiastersPerKg',
    ]) {
      expect(consumerSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('frozen target contract shape is recorded in the report', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Boundary:   ProductCatalogReadRepository',
      'Operation:  listProductCatalog({required bool includeInactive})',
      'Read model: ProductCatalogReadModel',
      'includeInactive = user.permissions.canCreateStockAdjustment',
      'createdAt ASC, id ASC',
      'No contract expansion',
      'Next phase type:    Migration only',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
    for (final field in const [
      '| `id` | `String` | no | `products.id` |',
      '| `name` | `String` | no | `products.name` |',
      '| `code` | `String?` | yes | `products.code` |',
      '| `unit` | `GrainUnit` | no | `products.unit` through `GrainUnit.fromWireName` |',
      '| `isActive` | `bool` | no | `products.isActive` |',
      '| `referenceCostPricePiastersPerKg` | `int?` | yes | `products.referenceCostPricePiastersPerKg` |',
    ]) {
      expect(report, contains(field), reason: field);
    }
  });

  test('Phase 106Q freezes but does not implement the migration', () {
    final contract = _git(['show', '$_baseline:$_contractPath']);
    final adapter = _git(['show', '$_baseline:$_adapterPath']);
    final target = _git(['show', '$_baseline:$_targetPath']);

    expect(target, contains('_productRepository.listProducts('));
    expect(target, isNot(contains('_productCatalogReadRepository')));
    expect(target, isNot(contains('.listProductCatalog(')));
    expect(contract, contains('referenceCostPricePiastersPerKg'));
    expect(adapter, contains('products.referenceCostPricePiastersPerKg'));
    expect(
      _git([
        'diff',
        '--name-only',
        _baseline,
        _phase106qCommit,
        '--',
        'lib',
      ]).trim(),
      isEmpty,
    );
  });

  test('ProductCatalogReadModel contract is not expanded', () {
    final source = File(_contractPath).readAsStringSync();
    final modelBody = _bracedBody(
      source,
      source.indexOf('final class ProductCatalogReadModel'),
    );
    final fields = RegExp(r'final\s+(String\??|GrainUnit|bool|int\??)\s+'
            r'(\w+)\s*;')
        .allMatches(modelBody)
        .map((match) => match.group(2)!)
        .toSet();

    expect(fields, _frozenReadModelFields);
  });

  test(
      'history is preserved: 106O target migrated in 106P, 106Q frozen target '
      'still legacy', () {
    final purchased = File(_purchaseControllerPath).readAsStringSync();
    expect(purchased, contains('.listProductCatalog('));
    expect(purchased, isNot(contains('.listProducts(')));
    expect(purchased, isNot(contains('ProductRepository')));

    final historical = File(
            'docs/PHASE-106O-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md')
        .readAsStringSync();
    expect(historical, contains('**A — selected**'));
    expect(historical, contains('PRC-110'));

    final migration = File(
            'docs/PHASE-106P-MIGRATE-PURCHASE-CONTROLLER-PRODUCT-CATALOG-READ.md')
        .readAsStringSync();
    expect(migration, contains('Outcome A — FULL SUCCESS'));
    expect(migration, contains('PurchaseController.load'));
  });

  test('governing report contains every required freeze section', () {
    final report = File(_reportPath).readAsStringSync();
    for (final heading in const [
      'Phase identity',
      'Governing references',
      'Current contract snapshot',
      'Search methodology',
      'Reconciliation',
      'Full inventory',
      'Classification summary',
      'Candidate comparison',
      'Frozen target',
      'Rejected alternatives',
      'Scope freeze (Phase 106R)',
      'Files changed (Phase 106Q)',
      'Non-goals',
      'Verification evidence',
      'Final outcome',
    ]) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }
    expect(
        report,
        contains(
            'The user database was not opened, read, copied, or modified.'));
    expect(report, contains('No Push and no Tag are performed.'));
  });
}

Set<String> _gitGrepFiles(String pattern, String revision) {
  final output = _git(['grep', '-l', '-F', pattern, revision, '--', 'lib']);
  return output
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .map(
          (line) => line.substring(line.indexOf(':') + 1).replaceAll('\\', '/'))
      .toSet();
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

String _bracedBody(String source, int start) {
  if (start < 0) throw StateError('Missing declaration.');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace.');
}

int _occurrences(String source, String pattern) =>
    RegExp(RegExp.escape(pattern)).allMatches(source).length;
