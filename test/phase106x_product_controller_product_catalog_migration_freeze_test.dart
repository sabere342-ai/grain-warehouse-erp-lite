import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';

const _baseline = 'b7d5086b4194b0dc2682b54ea5aa8fc79b314e1a';
const _phase106xCommit = '30021696ab2667340e032832892d3c2ecc5dadd7';
const _controllerPath = 'lib/core/catalog/product_controller.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

void main() {
  group('Phase 106X ProductController catalog read migration', () {
    test('load preserves permissions, ordering, notes, and loading state',
        () async {
      final catalog = _CatalogFake(_snapshot);
      final writes = _WriteRepositoryFake();
      final controller = ProductController(
        productCatalogReadRepository: catalog,
        repository: writes,
      );
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      await controller.loadProducts(_owner);

      expect(catalog.receivedIncludeInactive, [true]);
      expect(writes.listCalls, 0);
      expect(controller.products.map((product) => product.id), [
        'prd-z',
        'prd-a',
      ]);
      expect(controller.products.first.notes, '  verbatim note  ');
      expect(controller.products.last.notes, isNull);
      expect(controller.products, isA<List<ProductCatalogReadModel>>());
      expect(loadingStates, [true, false]);

      await controller.loadProducts(_employee);

      expect(catalog.receivedIncludeInactive, [true, false]);
      expect(writes.listCalls, 0);
    });

    test('load failure behavior still propagates and leaves loading active',
        () async {
      final catalog = _CatalogFake(
        const [],
        failure: StateError('catalog unavailable'),
      );
      final writes = _WriteRepositoryFake();
      final controller = ProductController(
        productCatalogReadRepository: catalog,
        repository: writes,
      );

      await expectLater(controller.loadProducts(_owner), throwsStateError);

      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);
      expect(controller.products, isEmpty);
      expect(catalog.receivedIncludeInactive, [true]);
      expect(writes.listCalls, 0);
    });

    test('mutations stay on ProductRepository and refresh through catalog',
        () async {
      final catalog = _CatalogFake(_snapshot);
      final writes = _WriteRepositoryFake();
      final controller = ProductController(
        productCatalogReadRepository: catalog,
        repository: writes,
      );
      const draft = ProductDraft(
        name: 'Updated',
        unit: GrainUnit.kilogram,
        notes: 'write note',
      );

      expect(
        await controller.createProduct(user: _owner, draft: draft),
        isTrue,
      );
      expect(
        await controller.updateProduct(
          user: _owner,
          productId: 'prd-z',
          draft: draft,
        ),
        isTrue,
      );
      expect(
        await controller.setProductActive(
          user: _owner,
          productId: 'prd-z',
          isActive: false,
        ),
        isTrue,
      );

      expect(writes.createCalls, 1);
      expect(writes.updateCalls, 1);
      expect(writes.setActiveCalls, 1);
      expect(writes.listCalls, 0);
      expect(catalog.receivedIncludeInactive, [true, true, true]);
      expect(controller.products.first.notes, '  verbatim note  ');
    });
  });

  group('Phase 106X source freeze', () {
    test('read model has exactly the eight prior fields plus nullable notes',
        () {
      final source = _sourceAt(_phase106xCommit, _contractPath);
      final modelBody = _between(
        source,
        'final class ProductCatalogReadModel {',
        'abstract interface class ProductCatalogReadRepository',
      );
      final fields = RegExp(r'^  final ([^;]+);$', multiLine: true)
          .allMatches(modelBody)
          .map((match) => match.group(1))
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
      expect(modelBody, contains('required this.notes'));
    });

    test('Drift adapter maps the real nullable notes column without transforms',
        () {
      final source = File(_adapterPath).readAsStringSync();

      expect(source, contains('products.notes,'));
      expect(source, contains('notes: row.read(products.notes),'));
      expect(source, contains('OrderingTerm.asc(products.createdAt)'));
      expect(source, contains('OrderingTerm.asc(products.id)'));
      expect(source, contains('query.where(products.isActive.equals(true))'));
      expect(source, isNot(contains('.trim()')));
      expect(source, isNot(contains('notes ??')));
      expect(source, isNot(contains('listProducts(')));
    });

    test('only loadProducts uses catalog read with the frozen permission', () {
      final source = File(_controllerPath).readAsStringSync();
      final loadBody = _between(
        source,
        'Future<void> loadProducts(AppUser user)',
        'Future<bool> createProduct(',
      );

      expect(
        loadBody,
        contains('_productCatalogReadRepository.listProductCatalog('),
      );
      expect(
        loadBody,
        contains('includeInactive: user.permissions.canManageProducts'),
      );
      expect(loadBody, isNot(contains('listProducts(')));
      expect(loadBody, isNot(contains('getProductById')));
      expect(source, isNot(contains('int.parse(')));
      expect(
        RegExp(r'_productCatalogReadRepository\.listProductCatalog\(')
            .allMatches(source),
        hasLength(1),
      );
      expect(source, contains('final ProductRepository _repository;'));
      expect(source, contains('List<ProductCatalogReadModel> _products'));
      expect(source, isNot(contains('List<Product> _products')));
    });

    test('production composition injects read and write dependencies', () {
      final screen =
          File('lib/features/products/products_screen.dart').readAsStringSync();

      expect(
        screen,
        contains(
          'AppRepositories.productCatalogReadRepository',
        ),
      );
      expect(screen, contains('repository: AppRepositories.productRepository'));
      expect(screen, contains('ProductCatalogReadModel? product'));
      expect(screen, contains('final ProductCatalogReadModel product;'));
    });

    test('accepted migrations add ProductController and PRC-113 consumers', () {
      final baselineConsumers = _gitGrepFiles(
        '.listProductCatalog(',
        revision: _baseline,
      );
      final currentConsumers = _workingTreeFilesWith('.listProductCatalog(');
      final addedConsumers = currentConsumers.difference(baselineConsumers);
      final removedConsumers = baselineConsumers.difference(currentConsumers);

      expect(addedConsumers, {
        'lib/core/backup/backup_export.dart',
        'lib/core/backup/backup_restore_service.dart',
        'lib/core/backup/business_data_wipe_service.dart',
        _controllerPath,
        'lib/features/financial_reports/profitability_report_screen.dart',
      });
      expect(removedConsumers, isEmpty);
    });

    test('schema and generated Drift files are unchanged from the baseline',
        () {
      final result = Process.runSync(
        'git',
        [
          'diff',
          '--quiet',
          _baseline,
          '--',
          'lib/core/persistence',
        ],
        runInShell: false,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });
  });
}

final _snapshot = <ProductCatalogReadModel>[
  ProductCatalogReadModel(
    id: 'prd-z',
    name: 'First from repository',
    code: 'Z',
    unit: GrainUnit.ton,
    isActive: false,
    referenceCostPricePiastersPerKg: 2375,
    defaultSalePricePiastersPerKg: 3000,
    minimumSalePricePiastersPerKg: 2500,
    notes: '  verbatim note  ',
    createdAt: _now,
    updatedAt: _now,
  ),
  ProductCatalogReadModel(
    id: 'prd-a',
    name: 'Second from repository',
    code: null,
    unit: GrainUnit.kilogram,
    isActive: true,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
    createdAt: _now,
    updatedAt: _now,
  ),
];

final _now = DateTime.utc(2026, 8, 1);

final _owner = AppUser(
  id: 'owner-106x',
  name: 'Owner',
  phone: '01000000106',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-106x',
  name: 'Employee',
  phone: '01100000106',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final class _CatalogFake implements ProductCatalogReadRepository {
  _CatalogFake(this.snapshot, {this.failure});

  final List<ProductCatalogReadModel> snapshot;
  final Object? failure;
  final List<bool> receivedIncludeInactive = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    receivedIncludeInactive.add(includeInactive);
    final error = failure;
    if (error != null) {
      throw error;
    }
    return snapshot;
  }
}

final class _WriteRepositoryFake implements ProductRepository {
  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int setActiveCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) async {
    listCalls++;
    throw StateError('Legacy product list read must not be called.');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    createCalls++;
    return _writtenProduct;
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) async {
    updateCalls++;
    return _writtenProduct;
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    setActiveCalls++;
    return _writtenProduct;
  }
}

final _writtenProduct = Product(
  id: 'written-product',
  name: 'Written product',
  unit: GrainUnit.kilogram,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

Set<String> _gitGrepFiles(String pattern, {required String revision}) {
  final result = Process.runSync(
    'git',
    ['grep', '-l', '-F', pattern, revision, '--', 'lib'],
    runInShell: false,
  );
  if (result.exitCode != 0 && result.exitCode != 1) {
    throw StateError('${result.stdout}${result.stderr}');
  }
  return _lines(result.stdout.toString())
      .map((line) => line.replaceFirst('$revision:', ''))
      .toSet();
}

Set<String> _workingTreeFilesWith(String pattern) => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => file.readAsStringSync().contains(pattern))
    .map((file) => _relative(file.path))
    .toSet();

Iterable<String> _lines(String value) => value
    .split(RegExp(r'\r?\n'))
    .map((line) => line.trim().replaceAll('\\', '/'))
    .where((line) => line.isNotEmpty);

String _relative(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final normalizedRoot = Directory.current.path.replaceAll('\\', '/');
  return normalizedPath.replaceFirst('$normalizedRoot/', '');
}

String _sourceAt(String revision, String path) {
  final result = Process.runSync(
    'git',
    ['show', '$revision:$path'],
    runInShell: false,
  );
  if (result.exitCode != 0) {
    throw StateError('${result.stdout}${result.stderr}');
  }
  return result.stdout.toString();
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Expected source boundaries were not found.');
  }
  return source.substring(startIndex, endIndex);
}
