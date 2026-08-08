import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

const _controllerPath = 'lib/core/purchases/purchase_controller.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _phase106pCommit = '80ede9595b51c17d1b82f16a9198b91a9d9422d9';
const _purchasesScreenPath = 'lib/features/purchases/purchases_screen.dart';
const _supplierPurchasesScreenPath =
    'lib/features/purchases/supplier_purchases_screen.dart';

const _frozenReadModelFields = {
  'id',
  'name',
  'code',
  'unit',
  'isActive',
  'referenceCostPricePiastersPerKg',
};

const _catalogCallers = {
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

void main() {
  group('PurchaseController.load product catalog read migration', () {
    test('load reads products through ProductCatalogReadRepository only',
        () async {
      final catalog = _Catalog([
        _model('prd-wheat', 'قمح', isActive: true),
        _model('prd-inactive', 'شعير', isActive: false),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(catalog.readCalls, 1);
      expect(catalog.includeInactiveValues, [true]);
      expect(fixture.controller.isLoading, isFalse);
      expect(fixture.controller.products, hasLength(2));
      expect(fixture.purchases.readCalls, 1);
      expect(fixture.suppliers.readCalls, 1);
    });

    test('includeInactive follows the canCreatePurchaseIntake permission',
        () async {
      final ownerCatalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final employeeCatalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final ownerFixture = _fixture(catalog: ownerCatalog);
      final employeeFixture = _fixture(catalog: employeeCatalog);

      await ownerFixture.controller.load(_owner);
      await employeeFixture.controller.load(_employee);

      expect(ownerCatalog.includeInactiveValues, [true]);
      expect(employeeCatalog.includeInactiveValues, [false]);
      expect(ownerFixture.controller.products, hasLength(2));
      expect(employeeFixture.controller.products, hasLength(1));
      expect(employeeFixture.controller.products.single.id, 'prd-1');
    });

    test('load exposes id, name, and isActive from the read model', () async {
      final catalog = _Catalog([
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'شعير', isActive: false),
      ]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      final products = fixture.controller.products;
      expect(products, hasLength(2));
      expect(products[0].id, 'prd-1');
      expect(products[0].name, 'قمح');
      expect(products[0].isActive, isTrue);
      expect(products[1].id, 'prd-2');
      expect(products[1].name, 'شعير');
      expect(products[1].isActive, isFalse);
      expect(fixture.controller.productName('prd-2'), 'شعير');
      expect(fixture.controller.productName('missing'), 'صنف غير معروف');
    });

    test('empty catalog list loads without crash and stays empty', () async {
      final catalog = _Catalog(const []);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(fixture.controller.isLoading, isFalse);
      expect(fixture.controller.products, isEmpty);
      expect(catalog.readCalls, 1);
    });

    test('catalog error preserves the current error propagation', () async {
      final catalog =
          _Catalog(const [], error: StateError('catalog read failed'));
      final fixture = _fixture(catalog: catalog);

      await expectLater(
        fixture.controller.load(_owner),
        throwsA(
          isA<StateError>().having(
              (error) => error.message, 'message', 'catalog read failed'),
        ),
      );

      expect(fixture.controller.errorMessage, isNull);
      expect(fixture.purchases.writeCalls, 0);
      expect(fixture.suppliers.writeCalls, 0);
    });

    test('load is read-only and never writes', () async {
      final catalog = _Catalog([_model('prd-1', 'قمح', isActive: true)]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);

      expect(fixture.purchases.writeCalls, 0);
      expect(fixture.suppliers.writeCalls, 0);
      expect(catalog.readCalls, 1);
    });

    test('reload reads the catalog again without cache', () async {
      final catalog = _Catalog([_model('prd-1', 'قمح', isActive: true)]);
      final fixture = _fixture(catalog: catalog);

      await fixture.controller.load(_owner);
      catalog.items = [
        _model('prd-1', 'قمح', isActive: true),
        _model('prd-2', 'ذرة', isActive: true),
      ];
      await fixture.controller.load(_owner);

      expect(catalog.readCalls, 2);
      expect(fixture.controller.products, hasLength(2));
    });
  });

  group('Phase 106P architecture freeze', () {
    test(
        'PurchaseController.load no longer depends on the legacy read contract',
        () {
      final source = _compact(File(_controllerPath).readAsStringSync());
      final loadBody = _compact(_methodBody(
        File(_controllerPath).readAsStringSync(),
        'Future<void> load(AppUser user) async',
      ));

      expect(source, contains('ProductCatalogReadRepository'));
      expect(source, isNot(contains('ProductRepository')));
      expect(source, isNot(contains('_productRepository')));
      expect(loadBody,
          contains('_productCatalogReadRepository.listProductCatalog('));
      expect(
        loadBody,
        contains(
          'includeInactive:user.permissions.canCreatePurchaseIntake',
        ),
      );
      expect(loadBody, isNot(contains('listProducts(')));
      for (final forbidden in const [
        '.transaction(',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'restoreProductsIntoEmpty(',
        'clearForOwnerDataWipe(',
        '_purchaseRepository.createPurchaseIntake(',
        '_purchaseRepository.cancelPurchaseIntake(',
        'createSupplier(',
        'updateSupplier(',
        'setSupplierActive(',
      ]) {
        expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('ProductCatalogReadModel contract at the 106P commit is not expanded',
        () {
      final source = _git(['show', '$_phase106pCommit:$_contractPath']);
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
    });

    test('catalog callers include accepted consumers through Phase 106Z', () {
      final callers = _filesCalling('.listProductCatalog(')..sort();

      expect(callers, _catalogCallers.toList()..sort());
      for (final path in [
        _purchasesScreenPath,
        _supplierPurchasesScreenPath,
      ]) {
        final screen = _compact(File(path).readAsStringSync());
        expect(
          screen,
          contains(
            'productCatalogReadRepository:AppRepositories.productCatalogReadRepository',
          ),
          reason: path,
        );
      }
    });
  });
}

ProductCatalogReadModel _model(String id, String name,
    {required bool isActive}) {
  return ProductCatalogReadModel(
    id: id,
    name: name,
    code: null,
    unit: GrainUnit.kilogram,
    isActive: isActive,
    referenceCostPricePiastersPerKg: null,
    defaultSalePricePiastersPerKg: null,
    minimumSalePricePiastersPerKg: null,
    notes: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

_Fixture _fixture({required _Catalog catalog}) {
  final purchases = _Purchases(const []);
  final suppliers = _Suppliers(const []);
  final controller = PurchaseController(
    purchaseRepository: purchases,
    supplierRepository: suppliers,
    productCatalogReadRepository: catalog,
  );
  return _Fixture(
    controller: controller,
    catalog: catalog,
    purchases: purchases,
    suppliers: suppliers,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.catalog,
    required this.purchases,
    required this.suppliers,
  });

  final PurchaseController controller;
  final _Catalog catalog;
  final _Purchases purchases;
  final _Suppliers suppliers;
}

final class _Catalog implements ProductCatalogReadRepository {
  _Catalog(this.items, {this.error});

  List<ProductCatalogReadModel> items;
  final Object? error;
  int readCalls = 0;
  final List<bool> includeInactiveValues = [];

  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async {
    readCalls++;
    includeInactiveValues.add(includeInactive);
    final failure = error;
    if (failure != null) throw failure;
    final result = includeInactive
        ? items
        : items.where((product) => product.isActive).toList(growable: false);
    return List<ProductCatalogReadModel>.unmodifiable(result);
  }
}

final class _Purchases implements PurchaseRepository {
  _Purchases(this.items);

  final List<PurchaseIntake> items;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    readCalls++;
    return List<PurchaseIntake>.unmodifiable(items);
  }

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106P fake is read-only.');
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106P fake is read-only.');
  }
}

final class _Suppliers implements SupplierRepository {
  _Suppliers(this.items);

  final List<Supplier> items;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<List<Supplier>> listSuppliers({bool includeInactive = true}) async {
    readCalls++;
    return List<Supplier>.unmodifiable(items);
  }

  @override
  Future<Supplier> createSupplier(SupplierDraft draft) {
    writeCalls++;
    throw UnsupportedError('Phase 106P fake is read-only.');
  }

  @override
  Future<Supplier> updateSupplier({
    required String supplierId,
    required SupplierDraft draft,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106P fake is read-only.');
  }

  @override
  Future<Supplier> setSupplierActive({
    required String supplierId,
    required bool isActive,
  }) {
    writeCalls++;
    throw UnsupportedError('Phase 106P fake is read-only.');
  }
}

final DateTime _now = DateTime.utc(2026, 7, 30);

final _owner = AppUser(
  id: 'owner-106p',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-106p',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

List<String> _filesCalling(String pattern) {
  final results = <String>[];
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
  final process = Process.runSync('git', arguments);
  if (process.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${process.stderr}');
  }
  return process.stdout as String;
}

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');

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
