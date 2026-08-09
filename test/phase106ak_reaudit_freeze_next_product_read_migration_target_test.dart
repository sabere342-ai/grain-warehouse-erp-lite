import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '2fd2ef4519b1007f1080fe004cca8572c1fe0d54';
const _predecessorSubject =
    'PHASE 106AJ: migrate drift purchase product validation reads';
const _phase106akCommit = '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
const _phase106alSubject =
    'PHASE 106AL: migrate negative balance approval product fingerprint read';
const _phase106alCommit = 'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
const _phase106amSubject =
    'PHASE 106AM: migrate profitability activation product read';
const _phase106amCommit = '8802c2115a45785f8705764514f9c7d0250a050d';
const _phase106anSubject = 'Phase 106AN: migrate PRC-111 product read';
const _branch =
    'codex/phase-106ak-reaudit-freeze-next-product-read-migration-target';
const _phase106alBranch =
    'codex/phase-106al-migrate-negative-balance-approval-product-fingerprint-read';
const _phase106amBranch = 'codex/phase-106am-migrate-prc-108-product-read';
const _phase106anBranch = 'codex/phase-106an-migrate-prc-111-product-read';
const _phase107cBranch =
    'codex/phase-107c-backup-restore-checksum-verification-contract';
const _phase107dBranch = 'codex/phase-107d-governed-windows-package-installer';
const _reportPath =
    'docs/PHASE-106AK-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _predecessorReportPath =
    'docs/PHASE-106AJ-MIGRATE-DRIFT-PURCHASE-PRODUCT-VALIDATION-READS.md';
const _predecessorGuardPath =
    'test/phase106aj_migrate_drift_purchase_product_validation_reads_test.dart';
const _targetPath =
    'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart';
const _migratedPurchasePath =
    'lib/core/purchases/drift_purchase_repository.dart';
const _compositionPath = 'lib/app/app_repositories.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

const _migrated = <String, _Consumer>{
  'PRC-001': _Consumer('lib/core/documents/document_history.dart', 1),
  'PRC-002': _Consumer('lib/features/dashboard/dashboard_screen.dart', 1),
  'PRC-003':
      _Consumer('lib/core/inventory/inventory_attention_service.dart', 1),
  'PRC-004': _Consumer('lib/core/dashboard/dashboard_service.dart', 1),
  'PRC-010': _Consumer('lib/core/inventory/drift_inventory_repository.dart', 1),
  'PRC-014': _Consumer('lib/core/reports/report_repository.dart', 1),
  'PRC-101': _Consumer('lib/core/backup/backup_export.dart', 1),
  'PRC-102': _Consumer('lib/core/backup/backup_restore_service.dart', 1),
  'PRC-103': _Consumer('lib/core/backup/business_data_wipe_service.dart', 1),
  'PRC-104': _Consumer('lib/core/catalog/product_controller.dart', 1),
  'PRC-106': _Consumer('lib/core/inventory/drift_inventory_repository.dart', 1),
  'PRC-107': _Consumer('lib/core/inventory/inventory_controller.dart', 1),
  'PRC-109': _Consumer(_migratedPurchasePath, 2),
  'PRC-110': _Consumer('lib/core/purchases/purchase_controller.dart', 1),
  'PRC-112': _Consumer('lib/core/sales/sale_controller.dart', 1),
  'PRC-113': _Consumer(
    'lib/features/financial_reports/profitability_report_screen.dart',
    1,
  ),
  'PRC-105': _Consumer(_targetPath, 1),
  'PRC-108': _Consumer(
    'lib/core/inventory_valuation/profitability_activation_service.dart',
    1,
  ),
  'PRC-111': _Consumer('lib/core/sales/sale_repository.dart', 1),
};

const _remaining = <String, _Consumer>{
  'PRC-114': _Consumer(
    'lib/core/inventory/inventory_repository.dart',
    2,
    classification: 'Infrastructure/Test',
  ),
  'PRC-115': _Consumer(
    'lib/core/purchases/purchase_repository.dart',
    1,
    classification: 'Infrastructure/Test',
  ),
  'PRC-116': _Consumer(
    'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
    1,
    classification: 'Infrastructure/Test',
  ),
  'PRC-117': _Consumer(
    _compositionPath,
    1,
    classification: 'Infrastructure/Test',
  ),
  'PRC-118': _Consumer(
    'lib/core/catalog/drift_product_repository.dart',
    1,
    classification: 'Infrastructure/Test',
  ),
};

const _selectedTargets = {'PRC-105'};
const _expectedNextProductionFiles = {_targetPath, _compositionPath};

void main() {
  test('baseline, predecessor, report, and branch metadata are exact', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(
      _git(['log', '-1', '--format=%s', _baseline]).trim(),
      _predecessorSubject,
    );
    expect(File(_predecessorReportPath).existsSync(), isTrue);
    expect(File(_predecessorGuardPath).existsSync(), isTrue);
    expect(File(_reportPath).existsSync(), isTrue);
    expect(
      _git(['branch', '--show-current']).trim(),
      anyOf(_branch, _phase106alBranch, _phase106amBranch, _phase106anBranch,
          _phase107cBranch, _phase107dBranch),
    );

    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Phase 106AK is a re-audit, inventory reconciliation, target-selection, contract assessment, and freeze phase.',
      'Required and actual starting HEAD | `2fd2ef4519b1007f1080fe004cca8572c1fe0d54`',
      'codex/phase-106ak-reaudit-freeze-next-product-read-migration-target',
      'It does not migrate a production consumer.',
    ]) {
      expect(_compact(report), contains(_compact(statement)),
          reason: statement);
    }
  });

  test('inventory has 24 unique PRCs: 19 migrated and 5 remaining', () {
    expect(_migrated, hasLength(19));
    expect(_remaining, hasLength(5));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
      _migrated.keys.toSet().intersection(_remaining.keys.toSet()),
      isEmpty,
    );
    expect(_migrated, contains('PRC-109'));
    expect(_migrated, contains('PRC-105'));
    expect(_remaining, isNot(contains('PRC-109')));
  });

  test('remaining classification is exactly I/Test 5', () {
    final counts = <String, int>{};
    for (final consumer in _remaining.values) {
      counts.update(
        consumer.classification,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    expect(counts, {'Infrastructure/Test': 5});
    expect(
      _remaining.entries
          .where((entry) => entry.value.classification == 'Production')
          .map((entry) => entry.key)
          .toSet(),
      isEmpty,
    );
  });

  test('live source has exactly 6 legacy and 20 catalog calls', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 6);
    expect(_occurrences(joined, '.listProductCatalog('), 20);

    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProducts('))
          .map((entry) => entry.key)
          .toSet(),
      {for (final consumer in _remaining.values) consumer.path},
    );
    expect(
      sources.entries
          .where((entry) => entry.value.contains('.listProductCatalog('))
          .map((entry) => entry.key)
          .toSet(),
      {for (final consumer in _migrated.values) consumer.path},
    );
    for (final entry in _callsByPath(_remaining).entries) {
      expect(
        _occurrences(sources[entry.key]!, '.listProducts('),
        entry.value,
        reason: entry.key,
      );
    }
    for (final entry in _callsByPath(_migrated).entries) {
      expect(
        _occurrences(sources[entry.key]!, '.listProductCatalog('),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('governing report contains one complete row for every PRC', () {
    final report = File(_reportPath).readAsStringSync();
    final inventory = _between(
      report,
      '## 5. Complete reconciled 24-consumer inventory',
      '## 6. Migrated and remaining tables; numerical reconciliation',
    );
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(inventory),
      hasLength(24),
    );
    for (final id in [..._migrated.keys, ..._remaining.keys]) {
      expect(_occurrences(inventory, '| $id |'), 1, reason: id);
    }
    for (final statement in const [
      'Total consumers: 24',
      'Migrated: 16',
      'Remaining: 8',
      'Remaining Production: 3',
      'Remaining Infrastructure/Test: 5',
      'Legacy calls: 9',
      'Product Catalog calls: 17',
      'PRC-109 owns two catalog calls',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('PRC-109 is migrated at both documented validation methods', () {
    final source = File(_migratedPurchasePath).readAsStringSync();
    final createValidation = _methodBody(
      source,
      'Future<ProductCatalogReadModel> _validateProduct(String id) async',
    );
    final restoreValidation = _methodBody(
      source,
      'Future<void> _validateProductExists(String id) async',
    );
    expect(source, isNot(contains('.listProducts(')));
    expect(_occurrences(source, '.listProductCatalog('), 2);
    expect(_occurrences(createValidation, 'includeInactive: true'), 1);
    expect(_occurrences(restoreValidation, 'includeInactive: true'), 1);
    expect(
      createValidation,
      contains('products.where((value) => value.id == id).firstOrNull'),
    );
    expect(createValidation, contains("StateError('Product was not found.')"));
    expect(
      createValidation,
      contains("StateError('Inactive product cannot be used.')"),
    );
    expect(
      restoreValidation,
      contains('values.any((value) => value.id == id)'),
    );
  });

  test('the sole frozen PRC-105 target is now catalog-backed', () {
    expect(_selectedTargets, hasLength(1));
    expect(_selectedTargets.single, 'PRC-105');
    expect(_migrated, contains(_selectedTargets.single));

    final source = File(_targetPath).readAsStringSync();
    final findProduct = _methodBody(
      source,
      'Future<ProductCatalogReadModel?> _findProduct(String? id) async',
    );
    final requireProduct = _methodBody(
      source,
      'Future<ProductCatalogReadModel> _requireProduct(String id) async',
    );
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
    expect(findProduct, contains('if (value.id == id!.trim()) return value'));
    expect(
      requireProduct,
      contains('if (product == null || !product.isActive)'),
    );
    expect(
        _occurrences(source, 'product.updatedAt.toUtc().toIso8601String()'), 2);
  });

  test('freeze specifies fields, includeInactive, sufficiency, and next phase',
      () {
    final report = File(_reportPath).readAsStringSync();
    final frozen = _between(
      report,
      '## 9. Frozen next target specification',
      '## 10. Contract sufficiency assessment',
    );
    for (final statement in const [
      'FROZEN_TARGET_COUNT: 1',
      'FROZEN_TARGET_ID: PRC-105',
      'FROZEN_TARGET_CLASS: Production',
      'FROZEN_TARGET_CONSUMER: NegativeBalanceApprovalWorkflowService._findProduct/_requireProduct',
      'FROZEN_TARGET_FILE: lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
      'CURRENT_REPOSITORY: ProductRepository _productRepository',
      'CURRENT_CALL: _productRepository.listProducts(includeInactive: true)',
      'INCLUDE_INACTIVE: literal true, selected by the consumer, not permission/runtime state',
      'FIELDS_CONSUMED: id; isActive; updatedAt',
      'CONTRACT_SUFFICIENT: yes',
      'REQUIRED_EXPANSION: none',
      'RECOMMENDED_NEXT_PHASE: PHASE 106AL - Migrate Negative Balance Approval Product Fingerprint Read',
      'first exact match',
      'Repository errors propagate.',
    ]) {
      expect(frozen, contains(statement), reason: statement);
    }

    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('final String id;'));
    expect(contract, contains('final bool isActive;'));
    expect(contract, contains('final DateTime updatedAt;'));
    final adapter = File(_adapterPath).readAsStringSync();
    expect(adapter, contains('products.updatedAt'));
    expect(adapter, contains('updatedAt: row.read(products.updatedAt)!'));

    final nextScope = _between(
      report,
      '## 11. Expected Phase 106AL scope, risks, and test strategy',
      '## 12. Phase guards, verification, Git lineage, and changed files',
    );
    final productionPaths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(nextScope)
        .map((match) => match.group(0)!)
        .toSet();
    expect(productionPaths, _expectedNextProductionFiles);
  });

  test('the immutable Phase 106AK commit has no production or schema diff', () {
    expect(_git(['diff', _baseline, _phase106akCommit, '--', 'lib']).trim(),
        isEmpty);
    expect(
      _git(['diff', _baseline, _phase106akCommit, '--', _contractPath]).trim(),
      isEmpty,
    );
    expect(
      _git(['diff', _baseline, _phase106akCommit, '--', _adapterPath]).trim(),
      isEmpty,
    );

    final changed = <String>{
      ..._git(['diff', '--name-only', _baseline, _phase106akCommit])
          .split(RegExp(r'\r?\n'))
          .where((path) => path.isNotEmpty),
    };
    expect(changed, isNotEmpty);
    for (final path in changed) {
      expect(
        path.startsWith('docs/') || path.startsWith('test/'),
        isTrue,
        reason: path,
      );
      expect(path, isNot(contains('.g.dart')));
      expect(path, isNot(contains('migration.sql')));
    }

    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Production | `0`',
      'Generated | `0`',
      'Schema/migrations | `0`',
      'Phase 106AK does not implement that migration.',
      'No contract expansion',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('lineage preserves the exact Phase 106AL through 106AN children', () {
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
            .trim() ==
        'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
    if (head == _phase106akCommit) return;
    final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
    final parent = _git(['rev-parse', 'HEAD^']).trim();
    final atPhase106al =
        subject == _phase106alSubject && parent == _phase106akCommit;
    final atPhase106am =
        subject == _phase106amSubject && parent == _phase106alCommit;
    final atPhase106an =
        subject == _phase106anSubject && parent == _phase106amCommit;
    expect(atPhase106al || atPhase106am || atPhase106an, isTrue);
    expect(
      _git(['rev-list', '--count', '$_phase106akCommit..HEAD']).trim(),
      atPhase106an ? '3' : (atPhase106am ? '2' : '1'),
    );
  });
}

final class _Consumer {
  const _Consumer(
    this.path,
    this.callSites, {
    this.classification = 'Migrated',
  });

  final String path;
  final int callSites;
  final String classification;
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[entity.path.replaceAll('\\', '/')] = entity.readAsStringSync();
  }
  return sources;
}

Map<String, int> _callsByPath(Map<String, _Consumer> consumers) {
  final calls = <String, int>{};
  for (final consumer in consumers.values) {
    calls.update(
      consumer.path,
      (value) => value + consumer.callSites,
      ifAbsent: () => consumer.callSites,
    );
  }
  return calls;
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
