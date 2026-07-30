import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '1293bee8b634c45508da7bb91cd70adaf1a21f34';
const _reportPath =
    'docs/PHASE-106D-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONSUMER-TARGET.md';
const _selectedPath = 'lib/core/inventory/inventory_attention_service.dart';

const _legacyConsumerFiles = {
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
  'lib/features/financial_reports/profitability_report_screen.dart',
};

const _legacyInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_repository.dart',
  'lib/core/catalog/product_repository.dart',
};

const _migratedConsumerFiles = {
  'lib/core/documents/document_history.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

const _catalogInfrastructureFiles = {
  'lib/app/app_repositories.dart',
  'lib/core/catalog/drift_product_catalog_read_repository.dart',
  'lib/core/catalog/product_catalog_read_repository.dart',
};

void main() {
  test('required baseline exists and Phase 106D has no production diff', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    expect(
        _git(['diff', '--name-only', _baseline, '--', 'lib']).trim(), isEmpty);
    expect(_git(['status', '--short', '--', 'lib']).trim(), isEmpty);
  });

  test('all current legacy and migrated product-read surfaces are inventoried',
      () {
    final legacyFiles = _gitGrepFiles('.listProducts(')
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _gitGrepFiles('.listProductCatalog(')
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

    final inventoryIds = RegExp(
      r'^\| PRC-\d{3} \|',
      multiLine: true,
    ).allMatches(report).length;
    expect(inventoryIds, 21);
  });

  test('exactly one next consumer is selected and prior consumers are excluded',
      () {
    final report = _read(_reportPath);
    final selections = RegExp(
      r'^Selected target:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['InventoryAttentionService.loadAttention']);
    expect(
        report, contains('LocalDocumentHistoryRepository._productNamesById'));
    expect(report, contains('DashboardGuidanceState.load'));
    expect(report, contains('Already migrated'));
    expect(File(_selectedPath).existsSync(), isTrue);
  });

  test('selected class and method retain the exact legacy read dependency', () {
    final source = _read(_selectedPath);
    final body = _methodBody(
      source,
      'Future<List<InventoryAttentionItem>> loadAttention() async',
    );

    expect(source, contains('final class InventoryAttentionService'));
    expect(source, contains('final ProductRepository _productRepository;'));
    expect(body, contains('_productRepository.listProducts('));
    expect(body, contains('includeInactive: true'));
    expect(
      RegExp(r'\.listProducts\s*\(').allMatches(body).length,
      1,
    );
    expect(body, isNot(contains('productCatalogReadRepository')));
    expect(body, isNot(contains('listProductCatalog(')));
    expect(source, isNot(contains('product_catalog_read_repository.dart')));
  });

  test('selected fields, merge, classification, and ordering are frozen', () {
    final source = _read(_selectedPath);
    final body = _methodBody(
      source,
      'Future<List<InventoryAttentionItem>> loadAttention() async',
    );

    for (final statement in const [
      '_inventoryRepository.allProductBalancesKg()',
      'balances[product.id] ?? 0',
      'productId: product.id',
      'productName: product.name',
      'isActive: product.isActive',
      'if (type == null) continue',
      'a.type.index.compareTo(b.type.index)',
      'a.quantityKg.compareTo(b.quantityKg)',
      'a.productName.compareTo(b.productName)',
      'a.productId.compareTo(b.productId)',
      'List<InventoryAttentionItem>.unmodifiable(items)',
    ]) {
      expect(body, contains(statement), reason: statement);
    }

    expect(source, contains('if (quantityKg <= 0)'));
    expect(source, contains('if (quantityKg <= lowStockMaximumKg)'));
    expect(source, contains('static const int lowStockMaximumKg = 5'));
    expect(body, isNot(contains('product.code')));
    expect(body, isNot(contains('product.unit')));
  });

  test(
      'selected method remains read-only, fresh, uncached, and propagates errors',
      () {
    final body = _methodBody(
      _read(_selectedPath),
      'Future<List<InventoryAttentionItem>> loadAttention() async',
    );

    expect(body, isNot(contains('try {')));
    expect(body, isNot(contains('catch (')));
    expect(body, isNot(contains('createProduct(')));
    expect(body, isNot(contains('updateProduct(')));
    expect(body, isNot(contains('setProductActive(')));
    expect(body, isNot(contains('createMovement(')));
    expect(body, isNot(contains('transaction(')));
    expect(body, isNot(contains('cache')));
  });

  test('two genuine dashboard call chains reach the selected consumer', () {
    final dashboard = _read('lib/features/dashboard/dashboard_screen.dart');
    final alerts =
        _read('lib/features/dashboard/dashboard_alerts_section.dart');
    final service = _read('lib/core/dashboard/dashboard_service.dart');
    final composition = _read('lib/app/app_repositories.dart');

    expect(dashboard, contains('(widget.loadAlerts ?? OwnerAlertData.load)()'));
    expect(dashboard, contains('service: DashboardService('));
    expect(alerts, contains('InventoryAttentionService('));
    expect(alerts, contains('AppRepositories.productRepository'));
    expect(alerts, contains('attentionService.loadAttention()'));
    expect(service, contains('InventoryAttentionService('));
    expect(service, contains('_inventoryAttentionService.loadAttention()'));
    expect(
        composition, contains('_productRepository = DriftProductRepository'));
  });

  test('report freezes state, lifecycle, side effects, and the future shape',
      () {
    final report = _read(_reportPath);
    for (final heading in const [
      'Git baseline',
      'Scope',
      'Governing references',
      'Discovery methodology',
      'Complete consumer inventory',
      'Candidate analysis',
      'Scoring matrix',
      'Selected target',
      'Selection rationale',
      'Frozen current runtime path',
      'Frozen Migration Contract',
      'Required future migration shape',
      'Explicit exclusions',
      'Production diff',
      'Tests',
      'Verification results',
      'User database safety',
      'Residual risks',
      'Next atomic phase',
    ]) {
      expect(
        report,
        matches(RegExp('^## ${RegExp.escape(heading)}\\s*\$', multiLine: true)),
        reason: heading,
      );
    }

    for (final statement in const [
      'includeInactive: true',
      'String id',
      'String name',
      'bool isActive',
      'No cache',
      'No retry',
      'No production code changes.',
      'No diff under lib/.',
      'InventoryAttentionService.loadAttention',
      'AppRepositories.productCatalogReadRepository',
      'listProductCatalog(includeInactive: true)',
      'Phase 106E — Migrate InventoryAttentionService.loadAttention to Product Catalog Read Contract',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

Set<String> _gitGrepFiles(String pattern) {
  final output = _git(['grep', '-l', '-F', pattern, '--', 'lib']);
  return output
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.replaceAll('\\', '/'))
      .toSet();
}

String _git(List<String> arguments) {
  final result = Process.runSync('git', arguments, runInShell: false);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.join(' ')} failed: ${result.stderr}',
    );
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
  throw StateError('Missing closing brace for $declaration.');
}
