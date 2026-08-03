import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = 'bd5d287a56fd96f826c673d775226cb4ad45a247';
const _phase106aiCommit = '7acac87799fc8345671f356cce273d345c38b565';
const _phase106ajSubject =
    'PHASE 106AJ: migrate drift purchase product validation reads';
const _predecessorSubject =
    'PHASE 106AH: migrate drift inventory product lookup read';
const _reportPath =
    'docs/PHASE-106AI-REAUDIT-FREEZE-NEXT-PRODUCT-READ-MIGRATION-TARGET.md';
const _predecessorReportPath =
    'docs/PHASE-106AH-MIGRATE-DRIFT-INVENTORY-PRODUCT-LOOKUP-READ.md';
const _predecessorGuardPath =
    'test/phase106ah_migrate_drift_inventory_product_lookup_read_test.dart';
const _targetPath = 'lib/core/purchases/drift_purchase_repository.dart';
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
  'PRC-110': _Consumer('lib/core/purchases/purchase_controller.dart', 1),
  'PRC-112': _Consumer('lib/core/sales/sale_controller.dart', 1),
  'PRC-113': _Consumer(
    'lib/features/financial_reports/profitability_report_screen.dart',
    1,
  ),
  'PRC-109': _Consumer(_targetPath, 2),
};

const _remaining = <String, _Consumer>{
  'PRC-105': _Consumer(
    'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
    1,
    classification: 'F',
  ),
  'PRC-108': _Consumer(
    'lib/core/inventory_valuation/profitability_activation_service.dart',
    1,
    classification: 'F',
  ),
  'PRC-111': _Consumer(
    'lib/core/sales/sale_repository.dart',
    1,
    classification: 'F',
  ),
  'PRC-114': _Consumer(
    'lib/core/inventory/inventory_repository.dart',
    2,
    classification: 'I',
  ),
  'PRC-115': _Consumer(
    'lib/core/purchases/purchase_repository.dart',
    1,
    classification: 'I',
  ),
  'PRC-116': _Consumer(
    'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
    1,
    classification: 'I',
  ),
  'PRC-117': _Consumer('lib/app/app_repositories.dart', 1, classification: 'I'),
  'PRC-118': _Consumer(
    'lib/core/catalog/drift_product_repository.dart',
    1,
    classification: 'I',
  ),
};

const _selectedTargets = {'PRC-109'};
const _expectedNextProductionFiles = {
  _targetPath,
  _compositionPath,
};

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

    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Required baseline | `bd5d287a56fd96f826c673d775226cb4ad45a247`',
      'Actual starting HEAD | `bd5d287a56fd96f826c673d775226cb4ad45a247`',
      'codex/phase-106ai-reaudit-freeze-next-product-read-migration-target',
      'Phase 106AI is an audit and freeze phase only.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('inventory has 24 unique PRCs: 16 migrated and 8 remaining', () {
    expect(_migrated, hasLength(16));
    expect(_remaining, hasLength(8));
    final ids = [..._migrated.keys, ..._remaining.keys];
    expect(ids, hasLength(24));
    expect(ids.toSet(), hasLength(24));
    expect(
      _migrated.keys.toSet().intersection(_remaining.keys.toSet()),
      isEmpty,
    );
  });

  test('live source has exactly 9 legacy and 17 catalog calls', () {
    final sources = _dartSources();
    final joined = sources.values.join('\n');
    expect(_occurrences(joined, '.listProducts('), 9);
    expect(_occurrences(joined, '.listProductCatalog('), 17);

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

  test('remaining classification is exactly F3 and I5', () {
    final counts = <String, int>{};
    for (final consumer in _remaining.values) {
      counts.update(
        consumer.classification,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    expect(counts, {'F': 3, 'I': 5});
  });

  test('governing report contains one complete row for every PRC', () {
    final report = File(_reportPath).readAsStringSync();
    final inventory = _between(
      report,
      '## 5. Full reconciled inventory',
      '## 6. Inventory comparison and number reconciliation',
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
      'Migrated: 15',
      'Remaining: 9',
      'Legacy calls: 11',
      'Product Catalog calls: 15',
      'Remaining classification: F4 / I5',
      'F: 4 - PRC-105, PRC-108, PRC-109, PRC-111',
      'I: 5 - PRC-114, PRC-115, PRC-116, PRC-117, PRC-118',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('PRC-109 was the only frozen target and is catalog-backed in 106AJ', () {
    expect(_selectedTargets, hasLength(1));
    expect(_selectedTargets.single, 'PRC-109');
    expect(_migrated, contains(_selectedTargets.single));

    final source = File(_targetPath).readAsStringSync();
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
    expect(
      _compact(createValidation),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
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
      _compact(restoreValidation),
      contains(
        '_productCatalogReadRepository.listProductCatalog('
        'includeInactive:true',
      ),
    );
    expect(
        restoreValidation, contains('values.any((value) => value.id == id)'));
    expect(restoreValidation, isNot(contains('isActive')));
  });

  test('frozen target contract and exact future production scope are complete',
      () {
    final report = File(_reportPath).readAsStringSync();
    final frozen = _between(
      report,
      '## 9. Frozen next target',
      '## 10. Frozen next-phase production diff and contract',
    );
    for (final statement in const [
      'Frozen next target:',
      'PRC: PRC-109',
      'Consumer: DriftPurchaseRepository._validateProduct / _validateProductExists',
      'File: lib/core/purchases/drift_purchase_repository.dart',
      'Member/method: _validateProduct and _validateProductExists',
      'Current dependency: ProductRepository _productRepository',
      'Current call: _productRepository.listProducts(includeInactive: true) at two call sites',
      'Current includeInactive behavior: literal true at both call sites',
      'Fields consumed: id, isActive; exact id existence on restore',
      'Required ProductCatalogReadModel fields: id (String, non-null), isActive (bool, non-null)',
      'Contract expansion required: no',
      'Expected new dependency: ProductCatalogReadRepository _productCatalogReadRepository',
      'Expected new call: _productCatalogReadRepository.listProductCatalog(includeInactive: true) at both call sites',
      'Expected Production files: lib/core/purchases/drift_purchase_repository.dart; lib/app/app_repositories.dart',
      'Behavior that must remain identical:',
      'Forbidden scope:',
      'Required dedicated tests:',
      'Primary risks:',
      'Recommended next phase title: Phase 106AJ - Migrate Drift Purchase Product Validation Reads',
      'Recommended branch: codex/phase-106aj-migrate-drift-purchase-product-validation-reads',
    ]) {
      expect(frozen, contains(statement), reason: statement);
    }

    final scope = _between(
      report,
      '## 10. Frozen next-phase production diff and contract',
      '## 11. Risk and next-phase test plan',
    );
    final productionPaths = RegExp(r'^lib/[^\r\n]+\.dart$', multiLine: true)
        .allMatches(scope)
        .map((match) => match.group(0)!)
        .toSet();
    expect(productionPaths, _expectedNextProductionFiles);

    final contract = File(_contractPath).readAsStringSync();
    expect(contract, contains('final String id;'));
    expect(contract, contains('final bool isActive;'));
  });

  test('Phase 106AI has no production, contract, schema, or generated diff',
      () {
    expect(
      _git(['diff', _baseline, _phase106aiCommit, '--', 'lib']).trim(),
      isEmpty,
    );
    expect(
      _git(['diff', _baseline, _phase106aiCommit, '--', _contractPath]).trim(),
      isEmpty,
    );
    expect(
      _git(['diff', _baseline, _phase106aiCommit, '--', _adapterPath]).trim(),
      isEmpty,
    );

    final changed = <String>{
      ..._git(['diff', '--name-only', _baseline, _phase106aiCommit])
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
    }

    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Product migration implemented: none',
      'Contract expansion implemented: none',
      'Schema/migration/generated changes: none',
      'Production files changed: none',
      'Phase 106AI does not implement that migration.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('lineage is Phase 106AI or its single exact Phase 106AJ child', () {
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head == _phase106aiCommit) return;
    expect(_git(['rev-parse', 'HEAD^']).trim(), _phase106aiCommit);
    expect(
        _git(['log', '-1', '--format=%s', 'HEAD']).trim(), _phase106ajSubject);
    expect(
        _git(['rev-list', '--count', '$_phase106aiCommit..HEAD']).trim(), '1');
  });
}

final class _Consumer {
  const _Consumer(
    this.path,
    this.callSites, {
    this.classification = 'Accepted',
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
