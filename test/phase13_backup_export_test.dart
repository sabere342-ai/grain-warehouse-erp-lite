import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_screen.dart';

void main() {
  group('Phase 13 backup export', () {
    testWidgets('dashboard backup entry appears for owner only',
        (tester) async {
      await tester.pumpWidget(_dashboardHarness(user: _owner));
      await _pumpExpectedState(tester);

      expect(find.text('النسخ الاحتياطي'), findsOneWidget);
      expect(find.text('تصدير نسخة احتياطية'), findsOneWidget);

      await tester.pumpWidget(_dashboardHarness(user: _employee));
      await _pumpExpectedState(tester);

      expect(find.text('النسخ الاحتياطي'), findsNothing);
      expect(find.text('تصدير نسخة احتياطية'), findsNothing);
    });

    testWidgets('backup screen contains safety warnings and copy UI',
        (tester) async {
      final fixture = await tester.runAsync(_fixture);
      expect(fixture, isNotNull);

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(service: fixture!.service),
        ),
      );
      await _pumpExpectedState(tester);

      expect(find.text('النسخ الاحتياطي'), findsOneWidget);
      expect(find.text('إنشاء نسخة احتياطية'), findsOneWidget);
      expect(find.textContaining('للحفظ والاسترجاع الآمن'), findsOneWidget);
      expect(find.textContaining('الاسترجاع متاح فقط إلى نظام فارغ'),
          findsOneWidget);
      expect(find.textContaining('لا تشارك النسخة'), findsOneWidget);

      await tester.tap(find.text('إنشاء نسخة احتياطية'));
      await _pumpExpectedState(tester);

      expect(find.text('تم إنشاء النسخة الاحتياطية بنجاح.'), findsOneWidget);
      expect(find.text('نسخ بيانات النسخة'), findsOneWidget);
      expect(find.text('عدد الأصناف'), findsOneWidget);
      expect(find.text('عدد حركات المخزون'), findsOneWidget);
      expect(find.text('عدد المشتريات'), findsOneWidget);
      expect(find.text('عدد المبيعات'), findsOneWidget);
      expect(find.text('عدد سجلات المستندات'), findsOneWidget);
      expect(find.text('إصدار النسخة'), findsOneWidget);
    });

    testWidgets('backup screen blocks non-owner users', (tester) async {
      final fixture = await tester.runAsync(_fixture);
      expect(fixture, isNotNull);

      await tester.pumpWidget(
        _screenHarness(
          user: _employee,
          child: BackupExportScreen(service: fixture!.service),
        ),
      );
      await _pumpExpectedState(tester);

      expect(find.text('النسخ الاحتياطي متاح للمالك فقط.'), findsOneWidget);
      expect(find.text('إنشاء نسخة احتياطية'), findsNothing);
    });

    test('snapshot JSON contains metadata counts data and checksum', () async {
      final fixture = await _fixture();

      final result = await fixture.service.createBackup();
      final decoded = jsonDecode(result.jsonText) as Map<String, Object?>;
      final metadata = decoded['metadata'] as Map<String, Object?>;
      final counts = decoded['counts'] as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;

      expect(metadata['app'], 'grain-warehouse-erp-lite');
      expect(metadata['backupVersion'], 6);
      expect(metadata['generatedAt'], '2026-01-02T03:04:05.000Z');
      expect(metadata['restoreSupported'], isFalse);
      expect(metadata['warning'], contains('يمكن استرجاعها فقط إلى نظام فارغ'));
      expect(decoded['checksum'], isA<String>());
      expect(decoded['checksumNote'], contains('ليس ميزة تشفير'));

      expect(counts['products'], 1);
      expect(counts['inventoryMovements'], 2);
      expect(counts['suppliers'], 1);
      expect(counts['purchases'], 1);
      expect(counts['sales'], 1);
      expect(counts['documentHistory'], 2);

      expect(
          data.keys,
          containsAll([
            'products',
            'inventoryMovements',
            'suppliers',
            'purchases',
            'sales',
            'documentHistory',
          ]));
      expect(data['products'], isA<List<Object?>>());
      expect(data['inventoryMovements'], isA<List<Object?>>());
      expect(data['suppliers'], isA<List<Object?>>());
      expect(data['purchases'], isA<List<Object?>>());
      expect(data['sales'], isA<List<Object?>>());
      expect(data['documentHistory'], isA<List<Object?>>());
    });

    test('snapshot omits password token and session fields', () async {
      final fixture = await _fixture();

      final result = await fixture.service.createBackup();
      final lowerJson = result.jsonText.toLowerCase();

      expect(lowerJson, isNot(contains('password')));
      expect(lowerJson, isNot(contains('passwordhash')));
      expect(lowerJson, isNot(contains('token')));
      expect(lowerJson, isNot(contains('session')));
    });

    test('export does not mutate stock sales purchases or history', () async {
      final fixture = await _fixture();
      final beforeProducts = await fixture.products.listProducts();
      final beforeMovements = await fixture.inventory.listAllMovements();
      final beforePurchases = await fixture.purchases.listPurchaseIntakes();
      final beforeSales = await fixture.sales.listSales();
      final beforeHistory = await fixture.history.listHistory();
      final beforeHistoryIds = beforeHistory.map((entry) => entry.id).toList();

      await fixture.service.createBackup();

      expect(await fixture.products.listProducts(), beforeProducts);
      expect(await fixture.inventory.listAllMovements(), beforeMovements);
      expect(await fixture.purchases.listPurchaseIntakes(), beforePurchases);
      expect(await fixture.sales.listSales(), beforeSales);
      final afterHistory = await fixture.history.listHistory();
      expect(afterHistory.map((entry) => entry.id), beforeHistoryIds);
    });
  });
}

Future<_BackupFixture> _fixture() async {
  final products = LocalProductRepository();
  final suppliers = LocalSupplierRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final sales = LocalSaleRepository(
    productRepository: products,
    inventoryRepository: inventory,
  );
  final history = LocalDocumentHistoryRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    productRepository: products,
    inventoryRepository: inventory,
  );
  final supplier = await suppliers.createSupplier(
    const SupplierDraft(name: 'مورد القمح', phone: '01011112222'),
  );
  final product = await products.createProduct(
    const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
  );

  await purchases.createPurchaseIntake(
    PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: product.id,
      quantityKg: 1000,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 650,
      createdByUserId: _owner.id,
      notes: 'استلام شراء',
    ),
  );
  final backupCustomer = await LocalCustomerRepository().createCustomer(
    const CustomerDraft(name: 'عميل', isActive: true),
  );
  await sales.createSale(
    SaleDraft(
      productId: product.id,
      quantityKg: 250,
      salePriceQirshPerKg: 800,
      createdByUserId: _owner.id,
      createdByUserName: _owner.name,
      notes: 'بيع اختبار',
      customerId: backupCustomer.id,
    ),
  );

  final service = BackupExportService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    now: () => DateTime.utc(2026, 1, 2, 3, 4, 5),
  );

  return _BackupFixture(
    products: products,
    inventory: inventory,
    purchases: purchases,
    sales: sales,
    history: history,
    service: service,
  );
}

/// Pumps the two known frames for the auth/export state transition without
/// waiting for unrelated animations from a previous widget-test tree.
Future<void> _pumpExpectedState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Widget _dashboardHarness({required AppUser user}) {
  return _screenHarness(
    user: user,
    child: DashboardScreen(
      loadGuidance: () async => DashboardGuidanceState.empty(),
    ),
  );
}

Widget _screenHarness({
  required AppUser user,
  required Widget child,
}) {
  return AuthScope(
    controller: _authControllerFor(user),
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: child),
    ),
  );
}

AuthController _authControllerFor(AppUser user) {
  final controller = AuthController(repository: _StaticAuthRepository(user));
  addTearDown(controller.dispose);
  controller.initialize();
  return controller;
}

class _BackupFixture {
  const _BackupFixture({
    required this.products,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.service,
  });

  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final BackupExportService service;
}

class _StaticAuthRepository implements AuthRepository {
  const _StaticAuthRepository(this.user);

  final AppUser user;

  @override
  Future<AppUser> createFirstOwner({
    required String name,
    required String phone,
    required String password,
  }) {
    throw StateError('Not used in this test.');
  }

  @override
  Future<AppUser?> currentUser() async {
    return user;
  }

  @override
  Future<bool> hasOwner() async {
    return true;
  }

  @override
  Future<AppUser?> signIn({
    required String phone,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<AppUser?> verifyCredentials({
    required String phone,
    required String password,
  }) async =>
      null;

  @override
  Future<AppUser?> getUserById(String userId) async =>
      user.id == userId.trim() ? user : null;

  @override
  Future<void> signOut() async {}
}

final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-test',
  name: 'موظف',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
