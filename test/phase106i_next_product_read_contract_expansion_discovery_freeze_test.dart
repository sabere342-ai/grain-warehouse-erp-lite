import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = '812face11ab3b63f2252402ec0cb8960cc4af563';
const _reportPath =
    'docs/PHASE-106I-DISCOVER-FREEZE-NEXT-PRODUCT-READ-CONTRACT-EXPANSION.md';
const _selectedPath = 'lib/core/reports/report_repository.dart';
const _calculatorPath = 'lib/core/reports/business_summary_calculator.dart';
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
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/features/dashboard/dashboard_screen.dart',
};

void main() {
  test('baseline architecture has 21 consumers classified by the report', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);

    final legacyFiles = _gitGrepFiles('.listProducts(')
      ..removeAll(_legacyInfrastructureFiles);
    final migratedFiles = _gitGrepFiles('.listProductCatalog(');

    expect(legacyFiles, _legacyConsumerFiles);
    expect(migratedFiles, _migratedConsumerFiles);

    final report = File(_reportPath).readAsStringSync();
    expect(
      RegExp(r'^\| PRC-\d{3} \|', multiLine: true).allMatches(report).length,
      21,
    );
    for (final total in const [
      'A — Already Migrated and Accepted: 4',
      'B — Eligible Under Current Contract: 0',
      'C — Requires a Broader Read Contract: 4',
      'D — Higher-Risk Read Migration: 0',
      'E — Write-Coupled or Transaction-Safety Read: 12',
      'F — Single Lookup or Stream Requirement: 0',
      'G — Not Production-Reachable: 1',
      'H — Already Superseded or Duplicated: 0',
      'Total: 21',
    ]) {
      expect(report, contains(total), reason: total);
    }
  });

  test('the four accepted consumers remain on the narrow catalog boundary', () {
    for (final path in _migratedConsumerFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('.listProductCatalog('), reason: path);
      expect(source, isNot(contains('.listProducts(')), reason: path);
    }

    final dashboard =
        File('lib/core/dashboard/dashboard_service.dart').readAsStringSync();
    expect(dashboard, isNot(contains('ProductRepository')));
    expect(
      dashboard,
      contains('final ProductCatalogReadRepository '
          '_productCatalogReadRepository;'),
    );
  });

  test('LocalReportRepository is the single selected broader-contract target',
      () {
    final report = File(_reportPath).readAsStringSync();
    final selections = RegExp(
      r'^Selected expansion:\s*(.+)$',
      multiLine: true,
    ).allMatches(report).map((match) => match.group(1)!.trim()).toList();

    expect(selections, ['LocalReportRepository.dailyActivityReport']);
    expect(report,
        contains('Rejected broader candidate: ProductController.loadProducts'));
    expect(report, contains('Rejected broader candidate: SaleController.load'));
    expect(
        report,
        contains(
            'Rejected broader candidate: BackupExportService.createBackup'));
  });

  test('selected target is production reachable, read-only, and still legacy',
      () {
    final repository = File(_selectedPath).readAsStringSync();
    final classStart = repository.indexOf('class LocalReportRepository');
    final methodStart = repository.indexOf(
      'Future<DailyActivityReport> dailyActivityReport(',
      classStart,
    );
    final asyncStart = repository.indexOf(' async {', methodStart);
    final body = _bracedBody(repository, asyncStart);
    final controller =
        File('lib/core/reports/report_controller.dart').readAsStringSync();
    final screen =
        File('lib/features/reports/reports_screen.dart').readAsStringSync();
    final composition =
        File('lib/app/app_repositories.dart').readAsStringSync();

    expect(repository, contains('final ProductRepository _productRepository;'));
    expect(_occurrences(body, '_productRepository.listProducts('), 1);
    expect(body, contains('includeInactive: true'));
    expect(body, isNot(contains('.listProductCatalog(')));
    for (final forbidden in const [
      'createProduct(',
      'updateProduct(',
      'setProductActive(',
      'clearForOwnerDataWipe(',
      'restoreProductsIntoEmpty(',
      '.transaction(',
    ]) {
      expect(body, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(screen, contains('ReportController('));
    expect(screen, contains('AppRepositories.reportRepository'));
    expect(controller, contains('_repository.dailyActivityReport('));
    expect(
      composition,
      contains('static final LocalReportRepository reportRepository'),
    );
    expect(composition, contains('productRepository: productRepository'));
  });

  test('selected target needs exactly the frozen nullable reference cost field',
      () {
    final repository = File(_selectedPath).readAsStringSync();
    final calculator = File(_calculatorPath).readAsStringSync();

    for (final field in const [
      'product.id',
      'product.name',
      'product.unit.labelAr',
    ]) {
      expect(repository, contains(field), reason: field);
    }
    expect(
      calculator,
      contains('product?.referenceCostPricePiastersPerKg'),
    );
    expect(
      calculator,
      contains('product.referenceCostPricePiastersPerKg'),
    );
    for (final forbidden in const [
      'defaultSalePricePiastersPerKg',
      'minimumSalePricePiastersPerKg',
      'product.code',
      'product.notes',
      'product.createdAt',
      'product.updatedAt',
    ]) {
      expect('$repository\n$calculator', isNot(contains(forbidden)),
          reason: forbidden);
    }
  });

  test('future contract shape and query semantics are frozen in the report',
      () {
    final report = File(_reportPath).readAsStringSync();
    for (final statement in const [
      'Frozen boundary: ProductCatalogReadRepository',
      'Frozen method: listProductCatalog',
      'Frozen read model: ProductCatalogReadModel',
      'Frozen added field: int? referenceCostPricePiastersPerKg',
      'includeInactive: true',
      'createdAt ASC, id ASC',
      'products.referenceCostPricePiastersPerKg',
      'Errors propagate unchanged',
      'Every invocation performs a fresh source read',
      'No retry, fallback, cache, swallowing, or partial result',
      'No product, inventory, or transaction write',
      'Phase 106J — Extend ProductCatalogReadModel with Reference Cost',
    ]) {
      expect(report, contains(statement), reason: statement);
    }
  });

  test('Phase 106I freezes but does not implement the expansion', () {
    final contract = File(_contractPath).readAsStringSync();
    final adapter = File(_adapterPath).readAsStringSync();
    final selected = File(_selectedPath).readAsStringSync();

    expect(contract, isNot(contains('referenceCostPricePiastersPerKg')));
    expect(
        adapter, isNot(contains('products.referenceCostPricePiastersPerKg')));
    expect(selected, contains('_productRepository.listProducts('));
    expect(selected, isNot(contains('_productCatalogReadRepository')));
    expect(
      _git(['diff', '--name-only', _baseline, '--', 'lib']).trim(),
      isEmpty,
    );
  });

  test('governing report contains every required freeze section', () {
    final report = File(_reportPath).readAsStringSync();
    for (final heading in const [
      'Executive outcome',
      'Governing references',
      'Current contract snapshot',
      'Full consumer inventory',
      'Classification totals',
      'Delta from Phase 106F',
      'Broader-contract candidates',
      'Ranking matrix',
      'Selected expansion',
      'Rejected candidates',
      'Frozen interface',
      'Frozen read model',
      'Mapping matrix',
      'Query semantics',
      'Non-goals',
      'Atomic follow-up plan',
      'Verification evidence',
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

Set<String> _gitGrepFiles(String pattern) {
  final output = _git(['grep', '-l', '-F', pattern, 'HEAD', '--', 'lib']);
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
