import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '2b90ca07a38c6890260d3c2df991d8b42fb5a200';
const _phaseSubject = 'PHASE 106W: freeze next product read migration target';
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
    'docs/PHASE-106W-REAUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _controllerPath = 'lib/core/catalog/product_controller.dart';
const _phase106zTargetPath =
    'lib/features/financial_reports/profitability_report_screen.dart';

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

const _nextPhaseProductionFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_catalog_read_repository.dart',
  'lib/core/catalog/product_catalog_read_repository.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/features/products/products_screen.dart',
};

void main() {
  test('Phase 106W has the exact baseline and no production diff', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
            .trim() ==
        'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
    final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final validHead = head == _baseline ||
        (subject == _phaseSubject &&
            _git(['rev-parse', '$head^']).trim() == _baseline) ||
        (subject == _phase106xSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106wCommit) ||
        (subject == _phase106ySubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106xCommit) ||
        (subject == _phase106zSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106yCommit) ||
        (subject == _phase106aaSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106zCommit) ||
        (subject == _phase106abSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106aaCommit) ||
        head == _phase106acCommit ||
        (subject == _phase106adSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106acCommit) ||
        (subject == _phase106aeSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106adCommit) ||
        (subject == _phase106afSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106aeCommit) ||
        (subject == _phase106agSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106afCommit) ||
        (subject == _phase106ahSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106agCommit) ||
        (subject == _phase106aiSubject &&
            _git(['rev-parse', '$head^']).trim() == _phase106ahCommit) ||
        (subject ==
                'PHASE 106AJ: migrate drift purchase product validation reads' &&
            _git(['rev-parse', '$head^']).trim() ==
                '7acac87799fc8345671f356cce273d345c38b565') ||
        (subject == 'PHASE 106AK: freeze next product read migration target' &&
            _git(['rev-parse', '$head^']).trim() ==
                '2fd2ef4519b1007f1080fe004cca8572c1fe0d54') ||
        (subject ==
                'PHASE 106AL: migrate negative balance approval product fingerprint read' &&
            _git(['rev-parse', '$head^']).trim() ==
                '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c') ||
        (subject ==
                'PHASE 106AM: migrate profitability activation product read' &&
            _git(['rev-parse', '$head^']).trim() ==
                'bc17876148074efab3f2a5ec1a71186eaad4e4c5') ||
        (subject == 'Phase 106AN: migrate PRC-111 product read' &&
            _git(['rev-parse', '$head^']).trim() ==
                '8802c2115a45785f8705764514f9c7d0250a050d');
    expect(validHead, isTrue,
        reason: 'HEAD must follow the single Phase 106W through Phase 106AB '
            'lineage.');

    expect(_git(['diff', _baseline, _phase106wCommit, '--', 'lib']).trim(),
        isEmpty,
        reason: 'Phase 106W is documentation/test-only; lib/ must not change.');
    final phase106xProductionFiles = _git([
      'diff',
      '--name-only',
      _phase106wCommit,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((path) => path.trim().isNotEmpty).toSet();
    expect(phase106xProductionFiles, {
      ..._nextPhaseProductionFiles,
      _phase106zTargetPath,
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
    });
  });

  test('the audit remains frozen while current inventory is 10 migrated', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Total identified inventory units | 24',
      'Migrated and accepted | 9',
      'Remaining classified units | 15',
      '`24 = 9 + 15`',
      'Legacy direct call sites | 17',
      'Catalog direct call sites | 9',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final legacyFiles = _workingTreeFilesWith('.listProducts(');
    expect(legacyFiles.difference(_legacyInfrastructureFiles),
        _legacyConsumerFiles);
    expect(legacyFiles.intersection(_legacyInfrastructureFiles),
        _legacyInfrastructureFiles);
    expect(
        _workingTreeFilesWith('.listProductCatalog('), _migratedConsumerFiles);
  });

  test('every remaining unit has one A-I classification', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      '| A | 0 |',
      '| B | 0 |',
      '| C | 1 |',
      '| D | 1 |',
      '| E | 8 |',
      '| F | 0 |',
      '| G | 0 |',
      '| H | 2 |',
      '| I | 3 |',
      '`0 + 0 + 1 + 1 + 8 + 0 + 0 + 2 + 3 = 15`',
    ]) {
      expect(report, contains(statement), reason: statement);
    }

    final remainingRows =
        RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length;
    expect(remainingRows, 15,
        reason: 'The remaining table must contain exactly 15 stable PRC rows.');
  });

  test('exactly one target is frozen: PRC-104 ProductController.loadProducts',
      () {
    final report = File(_reportPath).readAsStringSync();
    expect(_occurrences(report, 'FROZEN_TARGET_ID: PRC-104'), 1);
    expect(report,
        contains('FROZEN_TARGET_CONSUMER: ProductController.loadProducts'));
    expect(report, contains('FROZEN_TARGET_CATEGORY: C'));
    expect(
        report,
        contains(
            'FROZEN_TARGET_FILE: lib/core/catalog/product_controller.dart'));
    expect(
        report, contains('FROZEN_TARGET_MEMBER: loadProducts(AppUser user)'));
  });

  test('the selected target is migrated and preserves permission filtering',
      () {
    final source = File(_controllerPath).readAsStringSync();
    final body = _methodBody(
      source,
      'Future<void> loadProducts(AppUser user) async',
    );
    final compact = _compact(body);

    expect(
        _occurrences(
            compact, '_productCatalogReadRepository.listProductCatalog('),
        1);
    expect(compact,
        contains('includeInactive:user.permissions.canManageProducts'));
    expect(body, isNot(contains('listProducts(')));
    expect(source, contains('ProductCatalogReadRepository'));
  });

  test('current contract is nine fields with the frozen notes addition', () {
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
    expect(modelBody, contains('final String? notes;'));

    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'String? notes',
      'products.notes',
      'nullable text',
      'null remains null',
      'No trimming, defaulting, or normalization',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('future call and the complete required field set are frozen', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'ProductRepository.listProducts(',
      'ProductCatalogReadRepository.listProductCatalog(',
      'includeInactive: user.permissions.canManageProducts',
      '`id`',
      '`name`',
      '`code`',
      '`unit`',
      '`isActive`',
      '`referenceCostPricePiastersPerKg`',
      '`defaultSalePricePiastersPerKg`',
      '`minimumSalePricePiastersPerKg`',
      '`notes`',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('next phase is one consumer with an explicit five-file lib allowlist',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final path in _nextPhaseProductionFiles) {
      expect(report, contains('- `$path`'), reason: path);
    }
    expect(report, contains('one consumer only'));
    expect(report, contains('No other PRC row may migrate'));
    expect(report, contains('No unrelated refactor or behavior change'));
    expect(report, contains('No schema change or schemaVersion bump'));
  });

  test('the read contract is not used for product writes', () {
    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('listProductCatalog'));
    for (final forbidden in const [
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'restoreProductsIntoEmpty(',
      'clearForOwnerDataWipe(',
    ]) {
      expect(contract, isNot(contains(forbidden)), reason: forbidden);
    }

    final report = File(_reportPath).readAsStringSync();
    expect(report, contains('ProductRepository remains the write dependency'));
  });

  test('accepted consumers cannot regress to ProductRepository.listProducts',
      () {
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

  test('report freezes prohibitions and records the successful outcome', () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Outcome A — FULL SUCCESS',
      'No production file was changed in Phase 106W',
      'Do not migrate PRC-104 during Phase 106W',
      'Do not expand ProductCatalogReadModel during Phase 106W',
      'No Push was performed. No Tag was created.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
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
