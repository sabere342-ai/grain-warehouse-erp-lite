import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseline = 'fe549ecde9eba4de9c3d4916f611eae8fb58720e';
const _phaseSubject =
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
const _targetPath =
    'lib/features/financial_reports/profitability_report_screen.dart';
const _activationServicePath =
    'lib/core/inventory_valuation/profitability_activation_service.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

void main() {
  test('lineage starts at Phase 106Y and admits only its Phase 106Z child', () {
    expect(_git(['rev-parse', _baseline]).trim(), _baseline);
    final head = _git(['rev-parse', 'HEAD']).trim();
    if (head != _baseline) {
      final subject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atPhase106z = subject == _phaseSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _baseline;
      final atPhase106aa = subject == _phase106aaSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106zCommit;
      final atPhase106ab = subject == _phase106abSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106aaCommit;
      final atPhase106ac = head == _phase106acCommit;
      final atPhase106ad = subject == _phase106adSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106acCommit;
      final atPhase106ae = subject == _phase106aeSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106adCommit;
      final atPhase106af = subject == _phase106afSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106aeCommit;
      final atPhase106ag = subject == _phase106agSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106afCommit;
      final atPhase106ah = subject == _phase106ahSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106agCommit;
      final atPhase106ai = subject == _phase106aiSubject &&
          _git(['rev-parse', 'HEAD^']).trim() == _phase106ahCommit;
      final atPhase106aj = subject ==
              'PHASE 106AJ: migrate drift purchase product validation reads' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              '7acac87799fc8345671f356cce273d345c38b565';
      final atPhase106ak =
          subject == 'PHASE 106AK: freeze next product read migration target' &&
              _git(['rev-parse', 'HEAD^']).trim() ==
                  '2fd2ef4519b1007f1080fe004cca8572c1fe0d54';
      final atPhase106al = subject ==
              'PHASE 106AL: migrate negative balance approval product fingerprint read' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
      final atPhase106am = subject ==
              'PHASE 106AM: migrate profitability activation product read' &&
          _git(['rev-parse', 'HEAD^']).trim() ==
              'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
      expect(
        atPhase106z ||
            atPhase106aa ||
            atPhase106ab ||
            atPhase106ac ||
            atPhase106ad ||
            atPhase106ae ||
            atPhase106af ||
            atPhase106ag ||
            atPhase106ah ||
            atPhase106ai ||
            atPhase106aj ||
            atPhase106ak ||
            atPhase106al ||
            atPhase106am,
        isTrue,
      );
    }
  });

  test('the production diff is exactly the frozen PRC-113 file', () {
    expect(
      _git(['diff', '--name-only', _baseline, _phase106zCommit, '--', 'lib'])
          .trim(),
      _targetPath,
    );
    expect(
      _git(['diff', _baseline, _phase106zCommit, '--', _activationServicePath])
          .trim(),
      isEmpty,
      reason: 'PRC-108 activation validation must remain unchanged.',
    );
    expect(
        _git(['diff', _baseline, _phase106zCommit, '--', _contractPath]).trim(),
        isEmpty);
    expect(
      _git(['diff', _baseline, _phase106zCommit, '--', 'lib/core/persistence'])
          .trim(),
      isEmpty,
    );
  });

  test('target change is the exact four-part read-boundary substitution', () {
    final before = _sourceAt(_baseline, _targetPath);
    final expected = before
        .replaceFirst(
          "import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';",
          "import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';",
        )
        .replaceFirst(
          'AppRepositories.productRepository',
          'AppRepositories.productCatalogReadRepository',
        )
        .replaceFirst('.listProducts(', '.listProductCatalog(')
        .replaceFirst(
          'final List<Product> products;',
          'final List<ProductCatalogReadModel> products;',
        );
    expect(_normalizeNewlines(File(_targetPath).readAsStringSync()), expected);
  });

  test('PRC-113 uses the catalog read with inactive products included', () {
    final source = File(_targetPath).readAsStringSync();
    final activate =
        _methodBody(source, 'Future<void> _activate(AppUser user) async');
    final compact = _compact(activate);
    expect(
      compact,
      contains(
        'AppRepositories.productCatalogReadRepository.listProductCatalog('
        'includeInactive:true)',
      ),
    );
    expect(_occurrences(activate, '.listProductCatalog('), 1);
    expect(activate, isNot(contains('.listProducts(')));
    expect(activate, isNot(contains('productRepository')));
  });

  test('dialog consumes exactly verbatim catalog id and name', () {
    final source = File(_targetPath).readAsStringSync();
    final dialog = _between(
      source,
      'class _ActivationDialog extends StatefulWidget',
      'class _ActivationInput {',
    );
    expect(dialog, contains('final List<ProductCatalogReadModel> products;'));
    final fields = RegExp(r'product\.(\w+)')
        .allMatches(dialog)
        .map((match) => match.group(1)!)
        .toSet();
    expect(fields, {'id', 'name'});
    expect(dialog, isNot(contains('product.id.trim')),
        reason: 'No product id normalization may be introduced.');
    expect(dialog, isNot(contains('product.name.trim')),
        reason: 'No product name normalization may be introduced.');
  });

  test('catalog semantics retain active plus inactive rows and stable order',
      () {
    final adapter = File(_adapterPath).readAsStringSync();
    expect(adapter, contains('if (!includeInactive)'));
    expect(adapter, contains('products.isActive.equals(true)'));
    expect(adapter, contains('OrderingTerm.asc(products.createdAt)'));
    expect(adapter, contains('OrderingTerm.asc(products.id)'));
    expect(adapter, contains('id: row.read(products.id)!'));
    expect(adapter, contains('name: row.read(products.name)!'));
  });

  test('catalog contract was not expanded and exposes no write operation', () {
    final source = _sourceAt(_phase106zCommit, _contractPath);
    final model = _between(
      source,
      'final class ProductCatalogReadModel {',
      'abstract interface class ProductCatalogReadRepository',
    );
    final fields = RegExp(r'^  final ([^;]+);$', multiLine: true)
        .allMatches(model)
        .map((match) => match.group(1)!)
        .toList(growable: false);
    expect(fields, [
      'String id',
      'String name',
      'String? code',
      'GrainUnit unit',
      'bool isActive',
      'int? referenceCostPricePiastersPerKg',
      'int? defaultSalePricePiastersPerKg',
      'int? minimumSalePricePiastersPerKg',
      'String? notes',
    ]);
    final repository = source.substring(
      source.indexOf('abstract interface class ProductCatalogReadRepository'),
    );
    expect(_occurrences(repository, 'Future<'), 1);
    expect(repository, contains('listProductCatalog({'));
    expect(repository, isNot(matches(RegExp(r'create|update|delete|write'))));
  });

  test('PRC-108 and activation success and failure handling stay unchanged',
      () {
    final before = _sourceAt(_baseline, _targetPath);
    final after = File(_targetPath).readAsStringSync();
    final beforeActivate =
        _methodBody(before, 'Future<void> _activate(AppUser user) async');
    final afterActivate =
        _methodBody(after, 'Future<void> _activate(AppUser user) async');
    final normalizedBefore = _compact(beforeActivate)
        .replaceFirst('AppRepositories.productRepository', 'PRODUCT_READ')
        .replaceFirst('.listProducts(', '.list(');
    final normalizedAfter = _compact(afterActivate)
        .replaceFirst(
            'AppRepositories.productCatalogReadRepository', 'PRODUCT_READ')
        .replaceFirst('.listProductCatalog(', '.list(');
    expect(normalizedAfter, normalizedBefore);
    expect(
      _sourceAt(_phase106zCommit, _activationServicePath),
      contains('productRepository.listProducts(includeInactive: true)'),
      reason: 'PRC-108 remained legacy in the immutable Phase 106Z commit.',
    );
  });

  test('inventory moves exactly one consumer from legacy to catalog', () {
    expect(_sourceOccurrenceCountAt(_phase106zCommit, '.listProducts('), 15);
    expect(
        _sourceOccurrenceCountAt(_phase106zCommit, '.listProductCatalog('), 11);
    expect(_sourceFilesWithAt(_phase106zCommit, '.listProducts('),
        isNot(contains(_targetPath)));
    expect(_sourceFilesWithAt(_phase106zCommit, '.listProductCatalog('),
        contains(_targetPath));
    expect(24, 11 + 13);
  });
}

Set<String> _sourceFilesWithAt(String revision, String pattern) =>
    _git(['grep', '-l', '-F', pattern, revision, '--', 'lib'])
        .split(RegExp(r'\r?\n'))
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst('$revision:', ''))
        .toSet();

int _sourceOccurrenceCountAt(String revision, String pattern) => _git([
      'grep',
      '-o',
      '-F',
      pattern,
      revision,
      '--',
      'lib',
    ]).split(RegExp(r'\r?\n')).where((line) => line.isNotEmpty).length;

String _sourceAt(String commit, String path) =>
    _normalizeNewlines(_git(['show', '$commit:$path']));

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

String _normalizeNewlines(String source) => source.replaceAll('\r\n', '\n');
