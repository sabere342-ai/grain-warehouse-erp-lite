import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '7300f5569f0617cf81606eddd062e73ec75c2de6';
const _phase106tCommit = 'ff60b6ad9d759bedac72948dc6544b15bdbc925c';
const _phase106tSubject =
    'PHASE 106T: freeze next product read migration target';
const _phase106uSubject =
    'PHASE 106U: expand product catalog read and migrate sale controller';
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
    'docs/PHASE-106T-RE-AUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath = 'lib/core/sales/sale_controller.dart';
const _salesScreenPath = 'lib/features/sales/sales_screen.dart';
const _dashboardShellPath = 'lib/features/dashboard/dashboard_shell.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';
const _purchaseControllerPath = 'lib/core/purchases/purchase_controller.dart';
const _inventoryControllerPath = 'lib/core/inventory/inventory_controller.dart';

const _legacyConsumerFiles = {
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/purchase_repository.dart',
  'lib/core/sales/sale_repository.dart',
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
};

const _migratedConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
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
  test('baseline lineage: Phase 106T starts from the single Phase 106S commit',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);

    final head = _git(['rev-parse', 'HEAD']).trim();
    final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atBaseline = head == _baseline;
    final afterFreeze = headSubject == _phase106tSubject &&
        _git(['rev-parse', '$head^']).trim() == _baseline;
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
    expect(
        atBaseline ||
            afterFreeze ||
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
            afterMigrateAL,
        isTrue,
        reason:
            'HEAD must be the 106S baseline (during development), the single '
            'Phase 106T freeze commit whose parent is exactly the 106S '
            'baseline, the Phase 106U migration, the proven Phase 106V '
            'commit, its single Phase 106W freeze child, or the single Phase '
            '106X migration child, the Phase 106Y freeze, or the Phase 106Z '
            'PRC-113 migration, the Phase 106AA freeze, or the Phase 106AB '
            'migration.');

    final commitCount =
        int.parse(_git(['rev-list', '--count', '$_baseline..HEAD']).trim());
    expect(commitCount >= 0 && commitCount <= 19, isTrue,
        reason:
            'Zero through nineteen commits may exist after the 106S baseline; '
            'an open number of commits must fail loudly.');
  });

  test('Phase 106T is discovery/freeze only: no production diff', () {
    expect(
        _git([
          'diff',
          '--name-only',
          _baseline,
          _phase106tCommit,
          '--',
          'lib',
        ]).trim(),
        isEmpty,
        reason:
            'No production file under lib/ may differ from the 106S baseline '
            'at the 106T commit.');
    final worktree = _git(['diff', '--name-only', '--', 'lib'])
        .trim()
        .split(RegExp(r'\r?\n'))
        .where((path) => path.trim().isNotEmpty)
        .toSet();
    expect(
      worktree.difference(const {
        'lib/core/catalog/product_catalog_read_repository.dart',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/app/app_repositories.dart',
        'lib/core/sales/sale_controller.dart',
        'lib/features/sales/sales_screen.dart',
        'lib/core/catalog/product_controller.dart',
        'lib/features/products/products_screen.dart',
        'lib/features/financial_reports/profitability_report_screen.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/backup/backup_restore_service.dart',
        'lib/core/backup/business_data_wipe_service.dart',
        'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
        'lib/core/inventory/drift_inventory_repository.dart',
        'lib/core/purchases/drift_purchase_repository.dart',
      }),
      isEmpty,
      reason: 'Any working-tree lib/ diff must be limited to the Phase 106U '
          'or Phase 106X permitted production files, Phase 106Z PRC-113, or '
          'the Phase 106AB/106AD backup migrations, or the Phase 106AF '
          'wipe-count migration.',
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

  test('reconciliation: total equals migrated plus remaining (24 = 8 + 16)',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Total identified consumers | 24',
      'Migrated | 8',
      'Remaining | 16',
      '`24 = 8 + 16` — exact match',
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

  test('classification: every remaining consumer has exactly one A-I class',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final total in const [
      'C — Requires a Broader Read Contract | 2',
      'F — Write-Coupled / Transaction-Integrity Read | 8',
      'G — Financial / Inventory / Accounting Criticality | 1',
      'H — Not Production-Reachable | 3',
      'I — False Positive (Infrastructure) | 2',
      'Sum of categories | 16',
      'Remaining inventory | 16',
      'Migrated and accepted | 8',
      'Total identified | 24',
    ]) {
      expect(report, contains(total), reason: total);
    }
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length,
      16,
      reason: 'The 106T report must inventory exactly the 16 remaining rows.',
    );
    expect(report, contains('Variance vs Phase 106Q explained by name'));
    expect(report, contains('`InventoryController.load` (PRC-107)'));
  });

  test('SaleController.load is the single selected migration target', () {
    final report = File(_reportPath).readAsStringSync();
    final decisions = RegExp(r'^\*\*Decision:\*\*\s+(.+)$', multiLine: true)
        .allMatches(report)
        .map((match) => match.group(1)!.trim())
        .toList();
    expect(decisions.length, 1,
        reason: 'Exactly one decision line must exist in the report.');
    expect(decisions.single, contains('SaleController.load'));
    expect(
      RegExp(r'^\| (PRC-\d{3}) \|.*\*\*C — selected \(expansion\)\*\*',
              multiLine: true)
          .allMatches(report)
          .map((match) => match.group(1)!)
          .toList(),
      ['PRC-112'],
    );
    expect(
        report,
        contains('Classification of target | C — Requires a '
            'Broader Read Contract'));
    expect(report, contains('The single frozen target for Phase 106U is:'));
    expect(report, contains('extend `ProductCatalogReadModel` with'));
    expect(report, contains('`defaultSalePricePiastersPerKg` (`int?`)'));
    expect(report, contains('`minimumSalePricePiastersPerKg` (`int?`)'));
    expect(report, contains('so that `SaleController.load` can migrate to'));
  });

  test('selected target is read-only, production reachable, on the boundary',
      () {
    final controller = File(_targetPath).readAsStringSync();
    final classStart = controller.indexOf('class SaleController');
    final methodStart =
        controller.indexOf('Future<void> load(AppUser user)', classStart);
    final asyncStart = controller.indexOf(' async {', methodStart);
    final body = _bracedBody(controller, asyncStart);

    expect(
        controller,
        contains('required ProductCatalogReadRepository '
            'productCatalogReadRepository'));
    expect(
        _occurrences(body, '_productCatalogReadRepository.listProductCatalog('),
        1);
    expect(body, contains('includeInactive: false'));
    expect(body, contains('.listProductCatalog('));
    expect(body, contains('_productCatalogReadRepository'));
    for (final forbidden in const [
      '.transaction(',
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'restoreProductsIntoEmpty(',
      'clearForOwnerDataWipe(',
      'createSale(',
      'createPurchaseIntake(',
    ]) {
      expect(body, isNot(contains(forbidden)), reason: forbidden);
    }

    final screen = File(_salesScreenPath).readAsStringSync();
    expect(screen, contains('SaleController('));
    expect(
      screen,
      contains('AppRepositories.productCatalogReadRepository'),
      reason: _salesScreenPath,
    );
    expect(
        File(_dashboardShellPath).readAsStringSync(), contains('SalesScreen'));
  });

  test('selected target needs exactly id, name, and the two sale prices', () {
    final controller = File(_targetPath).readAsStringSync();
    final screen = File(_salesScreenPath).readAsStringSync();
    final consumerSource = '$controller\n$screen';

    for (final field in const [
      'product.id',
      'product.name',
      'product.defaultSalePricePiastersPerKg',
      'product.minimumSalePricePiastersPerKg',
    ]) {
      expect(consumerSource, contains(field), reason: field);
    }
    for (final forbidden in const [
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
      'Frozen next target:',
      'SaleController.load',
      'Current call:',
      'ProductRepository.listProducts(includeInactive: false)',
      'Required future call:',
      'ProductCatalogReadRepository.listProductCatalog(includeInactive: false)',
      'Contract expansion (Phase 106U only):',
      'ProductCatalogReadModel.defaultSalePricePiastersPerKg  — int?, nullable, piasters per kg',
      'ProductCatalogReadModel.minimumSalePricePiastersPerKg  — int?, nullable, piasters per kg',
      'products.defaultSalePricePiastersPerKg  (column exists)',
      'products.minimumSalePricePiastersPerKg  (column exists)',
      'A null value is preserved as null',
      'includeInactive = false   (fixed, active products only)',
      'createdAt ASC, id ASC',
      'contract-expansion + single-consumer migration',
      'No other consumer migration (ProductController.loadProducts stays legacy).',
      'No fallback to the legacy listProducts anywhere.',
      'No schema change, no migration, no schemaVersion bump.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
    for (final permittedFile in const [
      'lib/core/catalog/product_catalog_read_repository.dart',
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
      'lib/core/sales/sale_controller.dart',
      'lib/features/sales/sales_screen.dart',
    ]) {
      expect(report, contains(permittedFile), reason: permittedFile);
    }
    expect(report, contains('Phase 106U'));
  });

  test('Phase 106T freezes but does not implement the migration', () {
    final contract = _git(['show', '$_baseline:$_contractPath']);
    final adapter = _git(['show', '$_baseline:$_adapterPath']);
    final target = _git(['show', '$_baseline:$_targetPath']);

    expect(target, contains('_productRepository.listProducts('));
    expect(target, isNot(contains('_productCatalogReadRepository')));
    expect(target, isNot(contains('.listProductCatalog(')));
    expect(contract, contains('referenceCostPricePiastersPerKg'));
    expect(adapter, contains('products.referenceCostPricePiastersPerKg'));
    expect(contract, isNot(contains('defaultSalePricePiastersPerKg')));
    expect(contract, isNot(contains('minimumSalePricePiastersPerKg')));
    expect(adapter, isNot(contains('products.defaultSalePricePiastersPerKg')));
    expect(adapter, isNot(contains('products.minimumSalePricePiastersPerKg')));
    expect(
      _git([
        'diff',
        '--name-only',
        _baseline,
        _phase106tCommit,
        '--',
        'lib',
      ]).trim(),
      isEmpty,
      reason: 'The 106T commit itself must not change any production file; the '
          'frozen expansion is implemented only by the single 106U commit.',
    );
  });

  test(
      'ProductCatalogReadModel contract reflects the frozen nine-field '
      'expansion', () {
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

  test('schemaVersion stays 15 and no fallback appears', () {
    final foundation = File('lib/core/persistence/foundation_database.dart')
        .readAsStringSync();
    expect(foundation, contains('int get schemaVersion => 15;'));

    final contract = File(_contractPath).readAsStringSync();
    final adapter = File(_adapterPath).readAsStringSync();
    expect(contract, isNot(contains('listProducts(')));
    expect(adapter, isNot(contains('listProducts(')));
    expect(adapter, isNot(contains('catch (')));
    expect(adapter, isNot(contains('retry')));
  });

  test('history is preserved: 106O and 106Q targets are not reopened', () {
    final purchased = File(_purchaseControllerPath).readAsStringSync();
    expect(purchased, contains('.listProductCatalog('));
    expect(purchased, isNot(contains('.listProducts(')));
    expect(purchased, isNot(contains('ProductRepository')));

    final inventory = File(_inventoryControllerPath).readAsStringSync();
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
  });

  test('governing report contains every required freeze section', () {
    final report = File(_reportPath).readAsStringSync();
    for (final heading in const [
      '14.1 Executive summary',
      '14.2 Baseline verification',
      '14.3 Search methodology',
      '14.4 Reconciliation',
      '14.5 Full consumer inventory',
      '14.6 Migrated consumers',
      '14.7 Remaining consumers',
      '14.8 Candidate comparison',
      '14.9 Selected target',
      '14.10 Frozen migration contract (Phase 106U)',
      '14.11 Non-goals',
      '14.12 Files changed',
      '14.13 Verification',
      '14.14 Git evidence',
      'Final outcome',
    ]) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }
    expect(report, contains('open, read, copy, or modify the user database.'));
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
