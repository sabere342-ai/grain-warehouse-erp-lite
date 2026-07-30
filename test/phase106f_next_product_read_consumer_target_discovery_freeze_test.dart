import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '9f97637b71b91529a17faa7c2ce316294da02ac7';
const _reportPath =
    'docs/PHASE-106F-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONSUMER-TARGET.md';
const _selectedPath = 'lib/core/dashboard/dashboard_service.dart';

const _legacyConsumerFiles = {
  'lib/core/backup/backup_export.dart',
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
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
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
};

const _migratedConsumerFiles = {
  'lib/core/documents/document_history.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

const _catalogInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_catalog_read_repository.dart',
  'lib/core/catalog/product_catalog_read_repository.dart',
};

void main() {
  test('Phase 106E baseline exists and Phase 106F changes no production file',
      () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(
      _git(['diff', '--name-only', _baseline, '--', 'lib']).trim(),
      isEmpty,
    );
  });

  test('all legacy and migrated product read surfaces are inventoried', () {
    final legacyFiles = _gitGrepFiles('.listProducts(', _baseline)
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _gitGrepFiles('.listProductCatalog(', _baseline)
      ..removeAll(_catalogInfrastructureFiles);

    expect(legacyFiles, _legacyConsumerFiles);
    expect(migratedFiles, _migratedConsumerFiles);

    final report = _read(_reportPath);
    for (final path in {
      ..._legacyConsumerFiles,
      ..._legacyInfrastructureFiles,
      ..._migratedConsumerFiles,
      ..._catalogInfrastructureFiles,
    }) {
      expect(report, contains(path), reason: path);
    }
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length,
      21,
    );
  });

  test('the three prior consumers use the frozen catalog boundary', () {
    final history = _read('lib/core/documents/document_history.dart');
    final guidance = _classBody(
      _read('lib/features/dashboard/dashboard_screen.dart'),
      'class DashboardGuidanceState',
    );
    final attention =
        _read('lib/core/inventory/inventory_attention_service.dart');

    expect(
        history, contains('_productCatalogReadRepository.listProductCatalog('));
    expect(guidance, contains('productCatalogReadRepository'));
    expect(guidance, contains('.listProductCatalog(includeInactive: true)'));
    expect(attention,
        contains('_productCatalogReadRepository.listProductCatalog('));
    expect(attention, isNot(contains('ProductRepository')));
  });

  test('exactly DashboardService.load is frozen as the next target', () {
    final report = _read(_reportPath);
    final selections = RegExp(
      r'^Selected target:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['DashboardService.load']);
    expect(File(_selectedPath).existsSync(), isTrue);
    expect(report, contains('A — Already migrated: 3'));
    expect(report, contains('B — Eligible with current frozen contract: 1'));
    expect(report, contains('D — Requires broader read contract: 4'));
    expect(
        report, contains('E — Write-coupled or transactional safety read: 12'));
    expect(report, contains('H — Not production reachable: 1'));
  });

  test('selected method deliberately retains its exact legacy dependency', () {
    final source = _read(_selectedPath);
    final body = _methodBody(source, 'Future<DashboardData> load() async');

    expect(source, contains('final ProductRepository _productRepository;'));
    expect(body, contains('_productRepository.listProducts('));
    expect(body, contains('includeInactive: true'));
    expect(_occurrences(body, '.listProducts('), 1);
    expect(body, isNot(contains('_productCatalogReadRepository')));
    expect(body, isNot(contains('.listProductCatalog(')));
  });

  test('selected product projection and observable behavior are frozen', () {
    final body = _methodBody(
      _read(_selectedPath),
      'Future<DashboardData> load() async',
    );

    for (final statement in const [
      'final products =',
      'p.name.contains(',
      'wheatProduct.first.id',
      'balances[wheatProduct.first.id] ?? 0',
      'products.isNotEmpty || allSales.isNotEmpty',
      '_inventoryAttentionService.loadAttention()',
    ]) {
      expect(body, contains(statement), reason: statement);
    }
    for (final forbidden in const [
      'product.code',
      'product.unit',
      'defaultSalePricePiastersPerKg',
      'minimumSalePricePiastersPerKg',
      'referenceCostPricePiastersPerKg',
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'watchProducts(',
      'cache',
      'retry',
    ]) {
      expect(body, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('frozen contract supplies every product field selected method needs',
      () {
    final contract = _read(
      'lib/core/catalog/product_catalog_read_repository.dart',
    );
    final adapter = _read(
      'lib/core/catalog/drift_product_catalog_read_repository.dart',
    );

    for (final field in const [
      'final String id;',
      'final String name;',
      'final String? code;',
      'final GrainUnit unit;',
      'final bool isActive;',
    ]) {
      expect(contract, contains(field), reason: field);
    }
    expect(contract, contains('required bool includeInactive'));
    expect(adapter, contains('OrderingTerm.asc(products.createdAt)'));
    expect(adapter, contains('OrderingTerm.asc(products.id)'));
    expect(adapter, contains('products.isActive.equals(true)'));
  });

  test('protected production dashboard lifecycle reaches selected method', () {
    final screen = _read('lib/features/dashboard/dashboard_screen.dart');
    final controller = _read('lib/core/dashboard/dashboard_controller.dart');
    final composition = _read('lib/app/app_repositories.dart');

    expect(screen, contains('service: DashboardService('));
    expect(screen,
        contains('productRepository: AppRepositories.productRepository'));
    expect(
      screen,
      matches(
        RegExp(
          r'productCatalogReadRepository:\s*'
          r'AppRepositories\.productCatalogReadRepository',
        ),
      ),
    );
    expect(screen, contains('_controller.load();'));
    expect(controller, contains('_loadData = loadData ?? service!.load'));
    expect(controller, contains('_data = await _loadData();'));
    expect(composition,
        contains('_productRepository = DriftProductRepository(database)'));
    expect(
      composition,
      contains(
        '_productCatalogReadRepository = DriftProductCatalogReadRepository(database)',
      ),
    );
  });

  test('governing report freezes all required behavior and next phase only',
      () {
    final report = _read(_reportPath);
    for (final heading in const [
      'Outcome',
      'Git baseline and scope',
      'Discovery methodology',
      'Complete consumer inventory',
      'Classification distribution',
      'Eligible candidate comparison',
      'Selected target',
      'Frozen behavioral contract',
      'Runtime reachability proof',
      'Required Phase 106G shape',
      'Verification evidence',
      'User database safety',
      'Next phase only',
    ]) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }
    for (final statement in const [
      'DashboardService.load',
      'includeInactive: true',
      'createdAt ASC, id ASC',
      'No cache',
      'No retry',
      'No fallback',
      'No product write',
      'No diff under `lib/`',
      'AppRepositories.productCatalogReadRepository',
      'DriftProductCatalogReadRepository',
      'Phase 106G — Migrate DashboardService.load to ProductCatalogReadRepository',
      'The user database was not opened, read, copied, or modified.',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

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

String _classBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _bracedBody(source, start);
}

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  return _bracedBody(source, start);
}

String _bracedBody(String source, int start) {
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
