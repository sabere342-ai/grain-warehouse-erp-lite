import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '2b90ca07a38c6890260d3c2df991d8b42fb5a200';
const _phaseSubject = 'PHASE 106W: freeze next product read migration target';
const _reportPath =
    'docs/PHASE-106W-REAUDIT-AND-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _controllerPath = 'lib/core/catalog/product_controller.dart';

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
    final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final validHead = head == _baseline ||
        (subject == _phaseSubject &&
            _git(['rev-parse', '$head^']).trim() == _baseline);
    expect(validHead, isTrue,
        reason: 'HEAD must be the 106V baseline or its single 106W child.');

    expect(_git(['diff', _baseline, '--', 'lib']).trim(), isEmpty,
        reason: 'Phase 106W is documentation/test-only; lib/ must not change.');
    expect(_git(['diff', '--', 'lib']).trim(), isEmpty,
        reason: 'The working tree must have no production diff.');
  });

  test('the audit reconciles exactly 24 = 9 migrated + 15 remaining', () {
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

  test('the selected target is still legacy and preserves permission filtering',
      () {
    final source = File(_controllerPath).readAsStringSync();
    final body = _methodBody(
      source,
      'Future<void> loadProducts(AppUser user) async',
    );
    final compact = _compact(body);

    expect(_occurrences(compact, '_repository.listProducts('), 1);
    expect(compact,
        contains('includeInactive:user.permissions.canManageProducts'));
    expect(body, isNot(contains('listProductCatalog(')));
    expect(source, isNot(contains('ProductCatalogReadRepository')),
        reason: 'Phase 106W must not execute the frozen migration.');
  });

  test('current contract is eight fields and the only frozen addition is notes',
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
    expect(modelBody, isNot(contains('notes')));

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
