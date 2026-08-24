import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '7300f5569f0617cf81606eddd062e73ec75c2de6';
const _historicalScopeEndpoint = 'f521a97946d73829fef19f4f0d30a6d07b9f8051';
const _phase106tCommit = 'ff60b6ad9d759bedac72948dc6544b15bdbc925c';
const _phase106uSubject =
    'PHASE 106U: expand product catalog read and migrate sale controller';
const _phase106uCommit = '0ff8370b5cbc344973cdd968985a30c549f934d1';
const _phase106vCommit = '2b90ca07a38c6890260d3c2df991d8b42fb5a200';
const _phase106wSubject =
    'PHASE 106W: freeze next product read migration target';
const _phase106wCommit = 'b7d5086b4194b0dc2682b54ea5aa8fc79b314e1a';
const _phase106xSubject =
    'PHASE 106X: extend product catalog notes and migrate product controller';
const _phase106xCommit = '30021696ab2667340e032832892d3c2ecc5dadd7';
const _phase106ySubject =
    'PHASE 106Y: freeze next product read migration target';
const _phase106yCommit = 'fe549ecde9eba4de9c3d4916f611eae8fb58720e';
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
const _phase106agCommit = '25f4896b45fd8848a3aa5390e57a30926b9a9a24';
const _phase106ahSubject =
    'PHASE 106AH: migrate drift inventory product lookup read';
const _phase106ahCommit = 'bd5d287a56fd96f826c673d775226cb4ad45a247';
const _phase106aiSubject =
    'PHASE 106AI: freeze next product read migration target';
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

const _phase106xProductionFiles = {
  _contractPath,
  _adapterPath,
  _appRepositoriesPath,
  'lib/core/catalog/product_controller.dart',
  'lib/features/products/products_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
  'lib/core/backup/backup_checksum.dart',
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_preview.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/sales/drift_sale_repository.dart',
  'lib/core/sales/sale_repository.dart',
};

const _legacyConsumerFiles = {
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/purchase_repository.dart',
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
};

const _migratedConsumerFiles = {
  'lib/application/queries/load_product_catalog_query.dart',
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _catalogCallers = {
  'lib/application/queries/load_product_catalog_query.dart',
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
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
  'notes',
};

void main() {
  test('baseline lineage: Phase 106U starts from the single Phase 106T commit',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(_git(['rev-parse', _phase106tCommit]).trim(), _phase106tCommit);

    final head = _git(['rev-parse', 'HEAD']).trim();
    if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
            .trim() ==
        'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
    final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atFreeze = head == _phase106tCommit;
    final afterMigrateU = headSubject == _phase106uSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106tCommit;
    final atProvenV = head == _phase106vCommit;
    final afterFreezeW = headSubject == _phase106wSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106vCommit;
    final afterMigrateX = headSubject == _phase106xSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106wCommit;
    final afterFreezeY = headSubject == _phase106ySubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106xCommit;
    final afterMigrateZ = headSubject == _phase106zSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106yCommit;
    final afterFreezeAA = headSubject == _phase106aaSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106zCommit;
    final afterMigrateAB = headSubject == _phase106abSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106aaCommit;
    final atFreezeAC = head == _phase106acCommit;
    final afterMigrateAD = headSubject == _phase106adSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106acCommit;
    final afterFreezeAE = headSubject == _phase106aeSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106adCommit;
    final afterMigrateAF = headSubject == _phase106afSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106aeCommit;
    final afterFreezeAG = headSubject == _phase106agSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106afCommit;
    final afterMigrateAH = headSubject == _phase106ahSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106agCommit;
    final afterFreezeAI = headSubject == _phase106aiSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106ahCommit;
    final afterMigrateAJ = headSubject ==
            'PHASE 106AJ: migrate drift purchase product validation reads' &&
        _git(['rev-parse', '$head^']).trim() ==
            '7acac87799fc8345671f356cce273d345c38b565';
    final afterFreezeAK = headSubject ==
            'PHASE 106AK: freeze next product read migration target' &&
        _git(['rev-parse', '$head^']).trim() ==
            '2fd2ef4519b1007f1080fe004cca8572c1fe0d54';
    final afterMigrateAL = headSubject ==
            'PHASE 106AL: migrate negative balance approval product fingerprint read' &&
        _git(['rev-parse', '$head^']).trim() ==
            '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
    final afterMigrateAM = headSubject ==
            'PHASE 106AM: migrate profitability activation product read' &&
        _git(['rev-parse', '$head^']).trim() ==
            'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
    final afterMigrateAN =
        headSubject == 'Phase 106AN: migrate PRC-111 product read' &&
            _git(['rev-parse', '$head^']).trim() ==
                '8802c2115a45785f8705764514f9c7d0250a050d';
    expect(
        atFreeze ||
            afterMigrateU ||
            atProvenV ||
            afterFreezeW ||
            afterMigrateX ||
            afterFreezeY ||
            afterMigrateZ ||
            afterFreezeAA ||
            afterMigrateAB ||
            atFreezeAC ||
            afterMigrateAD ||
            afterFreezeAE ||
            afterMigrateAF ||
            afterFreezeAG ||
            afterMigrateAH ||
            afterFreezeAI ||
            afterMigrateAJ ||
            afterFreezeAK ||
            afterMigrateAL ||
            afterMigrateAM ||
            afterMigrateAN,
        isTrue,
        reason:
            'HEAD must be the Phase 106T freeze commit (during development) '
            'or follow its single Phase 106U migration, proven Phase 106V '
            'commit, single Phase 106W freeze child, and single Phase 106X '
            'migration child, Phase 106Y freeze, and Phase 106Z PRC-113 '
            'migration, Phase 106AA freeze, and Phase 106AB migration.');

    final commitCount =
        int.parse(_git(['rev-list', '--count', '$_baseline..HEAD']).trim());
    expect(commitCount >= 0 && commitCount <= 21, isTrue,
        reason:
            'Zero through twenty-one commits may exist after the 106S baseline; '
            'an open number of commits must fail loudly.');
  });

  test('Phase 106U and Phase 106X stay within their production allowlists', () {
    final phase106uDiff = _git([
      'diff',
      '--name-only',
      _phase106tCommit,
      _phase106uCommit,
      '--',
      'lib',
    ])
        .split(RegExp(r'\r?\n'))
        .where((path) =>
            path.trim().isNotEmpty && !_isPhase107GProductionPath(path))
        .toSet();
    expect(phase106uDiff, _permittedProductionFiles);

    final phase106xDiff = _git([
      'diff',
      '--name-only',
      _phase106wCommit,
      _historicalScopeEndpoint,
      '--',
      'lib',
    ])
        .split(RegExp(r'\r?\n'))
        .where((path) =>
            path.trim().isNotEmpty && !_isPhase107GProductionPath(path))
        .toSet();
    expect(phase106xDiff, _phase106xProductionFiles);
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
        reason: 'The current forward lineage must retain exactly the remaining '
            'legacy consumer files.');
    expect(migratedFiles, _migratedConsumerFiles,
        reason:
            'The current forward lineage must retain all migrated consumer files.');
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

  test('ProductCatalogReadModel contract is exactly the nine frozen fields',
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

  test('catalog callers include only accepted consumers through Phase 106Z',
      () {
    final callers = _workingTreeFilesWith('.listProductCatalog(').toList()
      ..sort();

    expect(callers, _catalogCallers.toList()..sort());
  });

  test('current schema is 16 and the Phase 106U adapter freeze remains intact',
      () {
    final foundation =
        File('$_persistencePath/foundation_database.dart').readAsStringSync();
    expect(foundation, contains('int get schemaVersion => 16;'));
    expect(
      _git([
        'diff',
        '--name-only',
        _phase106tCommit,
        _phase106uCommit,
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

bool _isPhase107GProductionPath(String path) =>
    path == 'lib/main.dart' ||
    path.startsWith('lib/core/trial/') ||
    path.startsWith('lib/features/trial/');

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
