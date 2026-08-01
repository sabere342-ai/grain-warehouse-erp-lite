import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '7300f5569f0617cf81606eddd062e73ec75c2de6';
const _phase106tCommit = 'ff60b6ad9d759bedac72948dc6544b15bdbc925c';
const _phase106uSubject =
    'PHASE 106U: expand product catalog read and migrate sale controller';
const _reportPath =
    'docs/PHASE-106U-EXPAND-PRODUCT-CATALOG-READ-AND-MIGRATE-SALE-CONTROLLER.md';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';
const _controllerPath = 'lib/core/sales/sale_controller.dart';
const _appRepositoriesPath = 'lib/app/app_repositories.dart';
const _salesScreenPath = 'lib/features/sales/sales_screen.dart';
const _persistencePath = 'lib/core/persistence';

const _permittedProductionFiles = {
  _contractPath,
  _adapterPath,
  _appRepositoriesPath,
  _controllerPath,
  _salesScreenPath,
};

const _legacyConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/purchases/purchase_repository.dart',
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
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

const _catalogCallers = {
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

const _frozenReadModelFields = {
  'id',
  'name',
  'code',
  'unit',
  'isActive',
  'referenceCostPricePiastersPerKg',
  'defaultSalePricePiastersPerKg',
  'minimumSalePricePiastersPerKg',
};

void main() {
  test('baseline lineage: Phase 106U starts from the single Phase 106T commit',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(_git(['rev-parse', _phase106tCommit]).trim(), _phase106tCommit);

    final head = _git(['rev-parse', 'HEAD']).trim();
    final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atFreeze = head == _phase106tCommit;
    final afterMigrateU = headSubject == _phase106uSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106tCommit;
    expect(atFreeze || afterMigrateU, isTrue,
        reason:
            'HEAD must be the Phase 106T freeze commit (during development) '
            'or the single Phase 106U commit whose parent is exactly the '
            '106T freeze commit.');

    final commitCount =
        int.parse(_git(['rev-list', '--count', '$_baseline..HEAD']).trim());
    expect(commitCount >= 0 && commitCount <= 2, isTrue,
        reason: 'Zero, one, or two commits may exist after the 106S baseline; '
            'an open number of commits must fail loudly.');
  });

  test('production scope is limited to the five permitted files', () {
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _phase106tCommit) {
      final diff = _git([
        'diff',
        '--name-only',
        _phase106tCommit,
        'HEAD',
        '--',
        'lib',
      ])
          .split(RegExp(r'\r?\n'))
          .where((path) => path.trim().isNotEmpty)
          .toSet();
      expect(diff, _permittedProductionFiles,
          reason:
              'The Phase 106U commit must change exactly the five permitted '
              'production files under lib/.');
    }

    final worktree = _git(['diff', '--name-only', '--', 'lib'])
        .split(RegExp(r'\r?\n'))
        .where((path) => path.trim().isNotEmpty)
        .toSet();
    expect(
      worktree.difference(_permittedProductionFiles),
      isEmpty,
      reason: 'Any working-tree lib/ diff must be limited to the five Phase '
          '106U permitted production files.',
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

  test('reconciliation: total equals migrated plus remaining (24 = 9 + 15)',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Total identified consumers | 24',
      'Migrated | 9',
      'Remaining | 15',
      '`24 = 9 + 15` — exact match',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final legacyFiles = _workingTreeFilesWith('.listProducts(')
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _workingTreeFilesWith('.listProductCatalog(');
    expect(legacyFiles, _legacyConsumerFiles,
        reason:
            'Exactly the 13 legacy consumer files must still call .listProducts(.');
    expect(migratedFiles, _migratedConsumerFiles,
        reason:
            'Exactly the 9 migrated consumer files must call .listProductCatalog(.');
  });

  test('all nine accepted consumers remain on the catalog boundary', () {
    for (final path in _migratedConsumerFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('.listProductCatalog('), reason: path);
    }
    for (final path in const [
      'lib/core/dashboard/dashboard_service.dart',
      'lib/core/documents/document_history.dart',
      'lib/core/inventory/inventory_attention_service.dart',
      'lib/core/inventory/inventory_controller.dart',
      'lib/core/purchases/purchase_controller.dart',
      'lib/core/reports/report_repository.dart',
      'lib/core/sales/sale_controller.dart',
      'lib/features/dashboard/dashboard_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('.listProducts(')), reason: path);
      expect(source, isNot(contains('ProductRepository')), reason: path);
    }
  });

  test('SaleController.load migrated without any legacy bypass', () {
    final source = File(_controllerPath).readAsStringSync();
    final loadBody = _methodBody(
      source,
      'Future<void> load(AppUser user) async',
    );

    expect(
        source,
        contains('required ProductCatalogReadRepository '
            'productCatalogReadRepository'));
    expect(source, isNot(contains('ProductRepository')));
    expect(source, isNot(contains('_productRepository')));
    expect(
      _occurrences(
          loadBody, '_productCatalogReadRepository.listProductCatalog('),
      1,
    );
    expect(loadBody, contains('includeInactive: false'));
    expect(loadBody, isNot(contains('listProducts(')));
    for (final forbidden in const [
      '.transaction(',
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'restoreProductsIntoEmpty(',
      'clearForOwnerDataWipe(',
      'createSale(',
      'cancelSale(',
      'listProducts(',
    ]) {
      expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('sales screen wires the catalog repository without a legacy fallback',
      () {
    final screen = _compact(File(_salesScreenPath).readAsStringSync());
    expect(
      screen,
      contains(
        'productCatalogReadRepository:AppRepositories.productCatalogReadRepository',
      ),
    );
    expect(screen, isNot(contains('productRepository:')));
    expect(screen, isNot(contains('AppRepositories.productRepository')));

    final app = File(_appRepositoriesPath).readAsStringSync();
    expect(
      app,
      contains('productCatalogReadRepository'),
    );
  });

  test('ProductCatalogReadModel contract is exactly the eight frozen fields',
      () {
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
    expect(source, contains('defaultSalePricePiastersPerKg'));
    expect(source, contains('minimumSalePricePiastersPerKg'));
  });

  test('no additional consumer migrated beyond SaleController.load', () {
    final callers = _workingTreeFilesWith('.listProductCatalog(').toList()
      ..sort();

    expect(callers, _catalogCallers.toList()..sort());
  });

  test('schemaVersion stays 15 and the adapter keeps no fallback', () {
    final foundation =
        File('$_persistencePath/foundation_database.dart').readAsStringSync();
    expect(foundation, contains('int get schemaVersion => 15;'));
    expect(
      _git([
        'diff',
        '--name-only',
        _phase106tCommit,
        'HEAD',
        '--',
        _persistencePath
      ]).trim(),
      isEmpty,
      reason: 'No schema or persistence file may change in the 106U commit.',
    );

    final adapter = File(_adapterPath).readAsStringSync();
    expect(adapter, isNot(contains('listProducts(')));
    expect(adapter, isNot(contains('catch (')));
    expect(adapter, isNot(contains('retry')));
    expect(adapter, contains('products.defaultSalePricePiastersPerKg'));
    expect(adapter, contains('products.minimumSalePricePiastersPerKg'));
  });

  test('history is preserved: 106O through 106T targets are not reopened', () {
    final purchased =
        File('lib/core/purchases/purchase_controller.dart').readAsStringSync();
    expect(purchased, contains('.listProductCatalog('));
    expect(purchased, isNot(contains('.listProducts(')));
    expect(purchased, isNot(contains('ProductRepository')));

    final inventory =
        File('lib/core/inventory/inventory_controller.dart').readAsStringSync();
    expect(inventory, contains('.listProductCatalog('));
    expect(inventory, isNot(contains('.listProducts(')));
    expect(inventory, isNot(contains('ProductRepository')));

    final o = File(
            'docs/PHASE-106O-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md')
        .readAsStringSync();
    expect(o, contains('**A — selected**'));
    expect(o, contains('PRC-110'));

    final p = File(
            'docs/PHASE-106P-MIGRATE-PURCHASE-CONTROLLER-PRODUCT-CATALOG-READ.md')
        .readAsStringSync();
    expect(p, contains('Outcome A — FULL SUCCESS'));
    expect(p, contains('PurchaseController.load'));

    final q = File(
            'docs/PHASE-106Q-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md')
        .readAsStringSync();
    expect(q, contains('**B — selected**'));
    expect(q, contains('PRC-107'));

    final r = File(
            'docs/PHASE-106R-MIGRATE-INVENTORY-CONTROLLER-PRODUCT-CATALOG-READ.md')
        .readAsStringSync();
    expect(r, contains('Outcome A — FULL SUCCESS'));
    expect(r, contains('InventoryController.load'));

    final s = File(
            'docs/PHASE-106S-PROVE-RUNTIME-INVENTORY-CONTROLLER-PRODUCT-CATALOG-READ-INTEGRATION.md')
        .readAsStringSync();
    expect(s, contains('Outcome A — FULL SUCCESS'));
    expect(s, contains('InventoryController.load'));

    final t = File(
            'docs/PHASE-106T-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md')
        .readAsStringSync();
    expect(t, contains('PRC-112'));
    expect(t, contains('The single frozen target for Phase 106U is:'));
  });

  test('governing report contains every required section', () {
    final report = File(_reportPath).readAsStringSync();
    for (final heading in const [
      '22.1 Executive summary',
      '22.2 Baseline verification',
      '22.3 Scope',
      '22.4 Reconciliation',
      '22.5 Contract expansion (Phase 106U)',
      '22.6 Migration (SaleController.load)',
      '22.7 Preserved behavior',
      '22.8 Production composition',
      '22.9 Files changed',
      '22.10 Tests',
      '22.11 Analysis and build',
      '22.12 Guard regression protection',
      '22.13 Git evidence',
      '22.14 Non-goals',
      'Final outcome',
    ]) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }
    expect(report, contains('Outcome A — FULL SUCCESS'));
    expect(report, contains('SaleController.load'));
    expect(report, contains('No Push was performed. No Tag was created.'));
  });
}

Set<String> _workingTreeFilesWith(String pattern) {
  final results = <String>{};
  final pending = <Directory>[Directory('lib')];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        pending.add(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        if (entity.readAsStringSync().contains(pattern)) {
          results.add(entity.path.replaceAll('\\', '/'));
        }
      }
    }
  }
  return results;
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
  return _bracedBody(source, start);
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

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
