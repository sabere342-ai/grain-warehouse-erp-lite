import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '39744e6b2d1581293da9f79bd3b8af79ee897f5c';
const _phase106oCommit = '4b7b1f2b2c32675a5c0f3aa0f96ef1227e7dd7b0';
const _phase106pCommit = '80ede9595b51c17d1b82f16a9198b91a9d9422d9';
const _phase106qCommit = 'f0341e9e070012953bce487c20401bf36eec1b87';
const _phase106rCommit = 'ad03bd0b27109ac2ec97d80ffa32fca22d0f41d9';
const _phase106sCommit = '7300f5569f0617cf81606eddd062e73ec75c2de6';
const _phase106tSubject =
    'PHASE 106T: freeze next product read migration target';
const _phase106tCommit = 'ff60b6ad9d759bedac72948dc6544b15bdbc925c';
const _phase106uSubject =
    'PHASE 106U: expand product catalog read and migrate sale controller';
const _phase106vCommit = '2b90ca07a38c6890260d3c2df991d8b42fb5a200';
const _phase106wSubject =
    'PHASE 106W: freeze next product read migration target';
const _phase106wCommit = 'b7d5086b4194b0dc2682b54ea5aa8fc79b314e1a';
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
const _reportPath =
    'docs/PHASE-106O-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _targetPath = 'lib/core/purchases/purchase_controller.dart';
const _purchasesScreenPath = 'lib/features/purchases/purchases_screen.dart';
const _supplierPurchasesScreenPath =
    'lib/features/purchases/supplier_purchases_screen.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

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
  'lib/core/purchases/purchase_controller.dart',
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
  'lib/core/reports/report_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

void main() {
  test('baseline architecture has 18 remaining consumers classified by report',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);

    final head = _git(['rev-parse', 'HEAD']).trim();
    final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final atBaseline = head == _baseline;
    final afterFreeze = headSubject ==
            'PHASE 106O: freeze next product read migration target' &&
        _git(['rev-parse', '$head^']).trim() == _baseline;
    final afterMigration = headSubject ==
            'PHASE 106P: migrate purchase controller product catalog read' &&
        _git(['rev-parse', '$head^']).trim() == _phase106oCommit;
    final afterReaudit = headSubject ==
            'PHASE 106Q: freeze next product read migration target' &&
        _git(['rev-parse', '$head^']).trim() == _phase106pCommit;
    final afterMigrateR = headSubject ==
            'PHASE 106R: migrate inventory controller product catalog read' &&
        _git(['rev-parse', '$head^']).trim() == _phase106qCommit;
    final afterProveS = headSubject ==
            'PHASE 106S: prove runtime inventory controller product catalog '
                'integration' &&
        _git(['rev-parse', '$head^']).trim() == _phase106rCommit;
    final afterFreezeT = headSubject == _phase106tSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106sCommit;
    final afterMigrateU = headSubject == _phase106uSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106tCommit;
    final atProvenV = head == _phase106vCommit;
    final afterFreezeW = headSubject == _phase106wSubject &&
        _git(['rev-parse', '$head^']).trim() == _phase106vCommit;
    final atMigrationX = head == _phase106xCommit &&
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
    expect(
        atBaseline ||
            afterFreeze ||
            afterMigration ||
            afterReaudit ||
            afterMigrateR ||
            afterProveS ||
            afterFreezeT ||
            afterMigrateU ||
            atProvenV ||
            afterFreezeW ||
            atMigrationX ||
            afterFreezeY ||
            afterMigrateZ ||
            afterFreezeAA ||
            afterMigrateAB ||
            atFreezeAC ||
            afterMigrateAD ||
            afterFreezeAE ||
            afterMigrateAF ||
            afterFreezeAG ||
            afterMigrateAH,
        isTrue,
        reason:
            'HEAD must follow the frozen Phase 106O through 106AA lineage, with '
            'the Phase 106Z migration, Phase 106AA freeze, and Phase 106AB '
            'migration children '
            'explicitly admitted.');

    final legacyFiles = _gitGrepFiles('.listProducts(', _baseline)
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _gitGrepFiles('.listProductCatalog(', _baseline);

    expect(legacyFiles, _legacyConsumerFiles);
    expect(migratedFiles, _migratedConsumerFiles);

    final report = File(_reportPath).readAsStringSync();
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length,
      18,
    );
    for (final total in const [
      'A — Read-Only, Current-Contract Fit, Standalone: 1',
      'B — Current-Contract Fit (broader context): 1',
      'C — Requires a Broader Read Contract: 2',
      'D — Requires a Single-Item Lookup: 0',
      'E — Requires a Stream / Reactive Read: 0',
      'F — Write-Coupled / Transaction-Integrity Read: 8',
      'G — Financial / Inventory / Accounting Criticality: 1',
      'H — Not Production-Reachable: 3',
      'I — False Positive (Infrastructure): 2',
      'Remaining inventory: 18',
      'Migrated and accepted: 6',
      'Total identified: 24',
    ]) {
      expect(report, contains(total), reason: total);
    }
  });

  test('the six accepted consumers remain on the catalog boundary', () {
    for (final path in _migratedConsumerFiles) {
      final source = _git(['show', '$_baseline:$path']);
      expect(source, contains('.listProductCatalog('), reason: path);
    }
    for (final path in const [
      'lib/core/dashboard/dashboard_service.dart',
      'lib/core/documents/document_history.dart',
      'lib/core/inventory/inventory_attention_service.dart',
      'lib/core/reports/report_repository.dart',
      'lib/features/dashboard/dashboard_screen.dart',
    ]) {
      expect(
          _git(['show', '$_baseline:$path']), isNot(contains('.listProducts(')),
          reason: path);
    }
  });

  test('PurchaseController.load is the single selected migration target', () {
    final report = File(_reportPath).readAsStringSync();
    final selections = RegExp(
      r'^Selected migration target:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['PurchaseController.load']);
    expect(report, contains('Classification: A'));
    expect(
        report,
        contains(
            'Phase 106P — Migrate `PurchaseController.load` to `ProductCatalogReadRepository`.'));
    expect(
      RegExp(r'^\| (PRC-\d{3}) \|.*\*\*A — selected\*\*', multiLine: true)
          .allMatches(report)
          .map((match) => match.group(1)!)
          .toList(),
      ['PRC-110'],
    );
  });

  test('selected target is production reachable, read-only, and still legacy',
      () {
    final controller = _git(['show', '$_baseline:$_targetPath']);
    final classStart = controller.indexOf('class PurchaseController');
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
      '_purchaseRepository.createPurchaseIntake(',
    ]) {
      expect(body, isNot(contains(forbidden)), reason: forbidden);
    }

    for (final path in [_purchasesScreenPath, _supplierPurchasesScreenPath]) {
      final screen = File(path).readAsStringSync();
      expect(screen, contains('PurchaseController('));
      expect(
        screen,
        matches(
          RegExp(
            r'AppRepositories\.(productRepository|productCatalogReadRepository)',
          ),
        ),
        reason: path,
      );
    }
  });

  test('selected target needs exactly id, name, and isActive', () {
    final controller = _git(['show', '$_baseline:$_targetPath']);
    final purchases = File(_purchasesScreenPath).readAsStringSync();
    final suppliers = File(_supplierPurchasesScreenPath).readAsStringSync();
    final consumerSource = '$controller\n$purchases\n$suppliers';

    for (final field in const [
      'product.id',
      'product.name',
      'product.isActive',
      'productName(intake.productId)',
    ]) {
      expect(consumerSource, contains(field), reason: field);
    }
    for (final forbidden in const [
      'defaultSalePricePiastersPerKg',
      'minimumSalePricePiastersPerKg',
      'product.code',
      'product.unit',
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
      'Required fields: id, name, isActive',
      'No lookup, no stream, no transaction, no write, no fallback, no cache',
      'includeInactive: user.permissions.canCreatePurchaseIntake',
      'createdAt ASC, id ASC',
      'No contract expansion',
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

  test('Phase 106O commit freezes but does not implement the migration', () {
    final contract = _git(['show', '$_baseline:$_contractPath']);
    final adapter = _git(['show', '$_baseline:$_adapterPath']);
    final target = _git(['show', '$_baseline:$_targetPath']);

    expect(target, contains('_productRepository.listProducts('));
    expect(target, isNot(contains('_productCatalogReadRepository')));
    expect(contract, contains('referenceCostPricePiastersPerKg'));
    expect(adapter, contains('products.referenceCostPricePiastersPerKg'));
    expect(
      _git(['diff', '--name-only', _baseline, _phase106oCommit, '--', 'lib'])
          .trim(),
      isEmpty,
    );
  });

  test('governing report contains every required freeze section', () {
    final report = File(_reportPath).readAsStringSync();
    for (final heading in const [
      'Executive outcome',
      'Governing references',
      'Current contract snapshot',
      'Search methodology',
      'Full consumer inventory',
      'Classification totals',
      'Migrated consumers (accepted, do not re-select)',
      'Production execution paths',
      'Field analysis',
      'Contract fit analysis',
      'Ranking matrix (current-contract-eligible candidates)',
      'Selected expansion',
      'Rejected candidates',
      'Frozen target contract',
      'Non-goals',
      'Atomic follow-up plan',
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
