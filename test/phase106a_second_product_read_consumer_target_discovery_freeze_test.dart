import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = 'a813a70d5a41e272046f320387572022797e8fd4';
const _phase106aCommit = 'fe618089672436d115ded9b02c4f1e17224cf7fb';
const _reportPath =
    'docs/PHASE-106A-DISCOVER-FREEZE-SECOND-PRODUCT-READ-CONSUMER-TARGET.md';
const _dashboardPath = 'lib/features/dashboard/dashboard_screen.dart';

const _phaseFiles = {
  _reportPath,
  'test/phase106a_second_product_read_consumer_target_discovery_freeze_test.dart',
};

const _productReadConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory/inventory_repository.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/inventory_valuation/synthetic_profitability_activation_service.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _productReadInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
  'lib/core/catalog/product_repository.dart',
};

void main() {
  test('Phase 105F baseline and frozen production boundary remain exact', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);

    for (final path in const [
      'lib/core/catalog/product_catalog_read_repository.dart',
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
      'lib/core/documents/document_history.dart',
      'lib/app/app_repositories.dart',
    ]) {
      expect(
        _gitExitCode(['diff', '--quiet', _baseline, '--', path]),
        0,
        reason: path,
      );
    }

    final phase105f = _git([
      'show',
      '$_baseline:docs/PHASE-105F-ACCEPT-FREEZE-FIRST-PRODUCT-CATALOG-READ-BOUNDARY-PILOT.md',
    ]);
    expect(phase105f, contains('LocalDocumentHistoryRepository'));
    expect(phase105f, contains('ProductCatalogReadRepository'));
    expect(phase105f, contains('DriftProductCatalogReadRepository'));
  });

  test('complete executable listProducts inventory is explicit and current',
      () {
    final discovered = _git([
      'grep',
      '-l',
      '-F',
      '.listProducts(',
      _phase106aCommit,
      '--',
      'lib',
    ])
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.substring(line.indexOf(':') + 1))
        .toSet()
      ..removeAll(_productReadInfrastructureFiles);

    expect(discovered, _productReadConsumerFiles);

    final report = _read(_reportPath);
    for (final path in _productReadConsumerFiles) {
      expect(report, contains(path), reason: path);
    }
    for (final path in _productReadInfrastructureFiles) {
      expect(report, contains(path), reason: path);
    }
  });

  test('exactly one real second consumer is selected and the pilot is excluded',
      () {
    final report = _read(_reportPath);
    final selections = RegExp(
      r'^Selected second product read consumer:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['DashboardGuidanceState.load']);
    expect(report, contains('LocalDocumentHistoryRepository'));
    expect(
      report,
      matches(
        RegExp(
          r'`?LocalDocumentHistoryRepository`?\s+is excluded',
          caseSensitive: false,
        ),
      ),
    );
    expect(File(_dashboardPath).existsSync(), isTrue);
  });

  test('selected target is a live production read with a proven call chain',
      () {
    final source = _git(['show', '$_phase106aCommit:$_dashboardPath']);
    final stateBody = _classBody(source, 'class DashboardGuidanceState');

    expect(
      source,
      contains('(widget.loadGuidance ?? DashboardGuidanceState.load)()'),
    );
    expect(stateBody, contains('static Future<DashboardGuidanceState> load()'));
    expect(
      stateBody,
      contains('AppRepositories.productRepository.listProducts('),
    );
    expect(stateBody, contains('includeInactive: true'));
    expect(stateBody, contains('productCount: products.length'));
    expect(stateBody, contains('listAllMovements()'));
    expect(stateBody, contains('listSales()'));
  });

  test('selected target is deliberately not migrated during Phase 106A', () {
    final source = _git(['show', '$_phase106aCommit:$_dashboardPath']);
    final stateBody = _classBody(source, 'class DashboardGuidanceState');

    expect(stateBody, contains('AppRepositories.productRepository'));
    expect(stateBody, contains('.listProducts('));
    expect(stateBody, isNot(contains('ProductCatalogReadRepository')));
    expect(stateBody, isNot(contains('productCatalogReadRepository')));
    expect(stateBody, isNot(contains('listProductCatalog(')));

    final report = _read(_reportPath);
    expect(
      report,
      contains('Target runtime path for the future migration:'),
    );
    expect(report, contains('AppRepositories.productCatalogReadRepository'));
    expect(report, contains('DriftProductCatalogReadRepository'));
  });

  test('Phase 106A changes no production file or frozen implementation', () {
    expect(
      _git([
        'diff',
        _baseline,
        _phase106aCommit,
        '--name-only',
        '--',
        'lib',
      ]).trim(),
      isEmpty,
    );

    final changedPaths = _git([
      'diff',
      _baseline,
      _phase106aCommit,
      '--name-only',
    ]).split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toSet();
    expect(changedPaths, _phaseFiles);
  });

  test('governing report freezes comparison, Phase 106B scope, and acceptance',
      () {
    final report = _read(_reportPath);
    const headings = [
      '1. Outcome',
      '2. Baseline and Branch',
      '3. Scope',
      '4. Governing Constraints',
      '5. Frozen Phase 105F Reference',
      '6. Discovery Method',
      '7. Definition of a Product Read Consumer',
      '8. Complete Candidate Inventory',
      '9. Candidate Runtime Paths',
      '10. Candidate Comparison Matrix',
      '11. Excluded Candidates',
      '12. Selected Second Consumer',
      '13. Selection Rationale',
      '14. Current Runtime Read Path',
      '15. Future Target Runtime Read Path',
      '16. Frozen Contract Compatibility',
      '17. Risks and Mitigations',
      '18. Phase 106B In Scope',
      '19. Phase 106B Out of Scope',
      '20. Phase 106B Acceptance Contract',
      '21. Files Expected to Change in Phase 106B',
      '22. Files Forbidden from Change in Phase 106B',
      '23. Test Evidence',
      '24. Production Code Diff Evidence',
      '25. Database Safety',
      '26. Verification Results',
      '27. Git Evidence',
      '28. Final Decision',
      '29. Proposed Next Phase Only',
    ];
    for (final heading in headings) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }

    for (final statement in const [
      'Candidate Comparison Matrix',
      'InventoryAttentionService',
      'Current runtime path:',
      'Target runtime path for the future migration:',
      'one consumer only',
      'No schema or migration changes',
      'String id',
      'GrainUnit unit',
      'The user production database was not opened, read, copied, or modified.',
      'Phase 106B — Migrate DashboardGuidanceState.load to the Frozen Product Catalog Read Contract',
    ]) {
      expect(report, contains(statement));
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _git(List<String> arguments) {
  final result = Process.runSync('git', arguments, runInShell: false);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.join(' ')} failed: ${result.stderr}',
    );
  }
  return result.stdout as String;
}

int _gitExitCode(List<String> arguments) =>
    Process.runSync('git', arguments, runInShell: false).exitCode;

String _classBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace for $declaration.');
}
