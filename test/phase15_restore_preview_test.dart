import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
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
import 'package:grain_warehouse_erp_lite/features/backup/backup_restore_preview_screen.dart';

void main() {
  group('Phase 15 restore preview validation', () {
    test('valid phase 14 backup JSON parses successfully', () async {
      final fixture = await _fixture();
      final jsonText = (await fixture.service.createBackup()).jsonText;

      final result = const BackupRestorePreviewService().preview(jsonText);

      expect(result.isValid, isTrue);
      expect(result.message, 'تم فحص النسخة بنجاح.');
      expect(result.summary!.backupVersion, 4);
      expect(result.summary!.generatedAt.toUtc(),
          DateTime.utc(2026, 7, 6, 15, 42, 30));
      expect(result.summary!.counts.products, 1);
      expect(result.summary!.counts.inventoryMovements, 2);
      expect(result.summary!.counts.suppliers, 1);
      expect(result.summary!.counts.purchases, 1);
      expect(result.summary!.counts.sales, 1);
      expect(result.summary!.counts.documentHistory, 2);
      expect(result.summary!.fileName, startsWith('grain-warehouse-backup-'));
      expect(result.summary!.checksum, isNotNull);
    });

    test('invalid JSON is rejected with friendly Arabic message', () {
      final result = const BackupRestorePreviewService().preview('{not-json');

      expect(result.isValid, isFalse);
      expect(result.message, contains('JSON غير صالح'));
      expect(result.technicalReason, 'invalid-json');
    });

    test('missing metadata is rejected', () {
      final result = const BackupRestorePreviewService().preview(
        jsonEncode({'counts': {}, 'data': {}}),
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('metadata'));
      expect(result.technicalReason, 'missing-metadata');
    });

    test('unsupported backupVersion is rejected', () async {
      final fixture = await _fixture();
      final backup = await _decodedBackup(fixture);
      (backup['metadata'] as Map<String, Object?>)['backupVersion'] = 99;

      final result =
          const BackupRestorePreviewService().preview(jsonEncode(backup));

      expect(result.isValid, isFalse);
      expect(result.message, contains('إصدار النسخة غير مدعوم'));
      expect(result.technicalReason, 'unsupported-version');
    });

    test('restoreSupported true is rejected', () async {
      final fixture = await _fixture();
      final backup = await _decodedBackup(fixture);
      (backup['metadata'] as Map<String, Object?>)['restoreSupported'] = true;

      final result =
          const BackupRestorePreviewService().preview(jsonEncode(backup));

      expect(result.isValid, isFalse);
      expect(result.technicalReason, 'restore-supported');
    });

    test('counts mismatch is rejected', () async {
      final fixture = await _fixture();
      final backup = await _decodedBackup(fixture);
      (backup['counts'] as Map<String, Object?>)['products'] = 2;

      final result =
          const BackupRestorePreviewService().preview(jsonEncode(backup));

      expect(result.isValid, isFalse);
      expect(result.message, contains('عدد السجلات لا يطابق'));
      expect(result.technicalReason, 'count-mismatch-products');
    });

    test('sensitive keys are rejected', () async {
      for (final key in [
        'password',
        'passwordHash',
        'token',
        'session',
        'secret',
      ]) {
        final fixture = await _fixture();
        final backup = await _decodedBackup(fixture);
        final data = backup['data'] as Map<String, Object?>;
        final products = data['products'] as List<Object?>;
        (products.first as Map<String, Object?>)[key] = 'hidden';

        final result =
            const BackupRestorePreviewService().preview(jsonEncode(backup));

        expect(result.isValid, isFalse, reason: 'Expected $key to fail');
        expect(result.technicalReason, 'sensitive-key');
      }
    });

    test('unknown extra safe fields do not break preview', () async {
      final fixture = await _fixture();
      final backup = await _decodedBackup(fixture);
      backup['extraSafeNote'] = 'ok';
      (backup['metadata'] as Map<String, Object?>)['operatorNote'] = 'safe';

      final result =
          const BackupRestorePreviewService().preview(jsonEncode(backup));

      expect(result.isValid, isTrue);
    });
  });

  group('Phase 15 restore preview UI', () {
    testWidgets('backup screen has preview entry', (tester) async {
      final fixture = await _fixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(service: fixture.service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فحص نسخة احتياطية'), findsOneWidget);
    });

    testWidgets('preview screen shows safety copy and input controls',
        (tester) async {
      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: const BackupRestorePreviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فحص نسخة احتياطية'), findsOneWidget);
      expect(find.textContaining('للفحص والمعاينة فقط'), findsOneWidget);
      expect(find.textContaining('لن يتم استرجاع أو تعديل أو حذف'),
          findsOneWidget);
      expect(find.text('الصق بيانات النسخة الاحتياطية هنا'), findsOneWidget);
      expect(find.text('فحص النسخة'), findsOneWidget);
      expect(find.text('مسح النص'), findsOneWidget);
    });

    testWidgets('valid JSON preview shows summary and safety warning',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _fixture();
      final jsonText = (await fixture.service.createBackup()).jsonText;

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: const BackupRestorePreviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), jsonText);
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();

      expect(find.text('تم فحص النسخة بنجاح.'), findsOneWidget);
      expect(find.text('الأصناف'), findsOneWidget);
      expect(find.text('حركات المخزون'), findsOneWidget);
      expect(find.text('الموردين'), findsOneWidget);
      expect(find.text('المشتريات'), findsOneWidget);
      expect(find.text('المبيعات'), findsOneWidget);
      expect(find.text('سجل المستندات'), findsOneWidget);
      expect(find.textContaining('يمكن الاسترجاع إلى نظام فارغ فقط'), findsOneWidget);
    });

    testWidgets('invalid JSON shows friendly error', (tester) async {
      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: const BackupRestorePreviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '{bad-json');
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();

      expect(find.text('تعذر فحص النسخة الاحتياطية.'), findsOneWidget);
      expect(find.textContaining('JSON غير صالح'), findsOneWidget);
    });

    testWidgets('non-owner users cannot use preview screen', (tester) async {
      await tester.pumpWidget(
        _screenHarness(
          user: _employee,
          child: const BackupRestorePreviewScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('هذه الأداة متاحة للمالك فقط.'), findsOneWidget);
      expect(find.text('فحص النسخة'), findsNothing);
    });

    test('preview action does not mutate existing repository data', () async {
      final fixture = await _fixture();
      final jsonText = (await fixture.service.createBackup()).jsonText;
      final beforeProducts = await fixture.products.listProducts();
      final beforeMovements = await fixture.inventory.listAllMovements();
      final beforePurchases = await fixture.purchases.listPurchaseIntakes();
      final beforeSales = await fixture.sales.listSales();
      final beforeHistoryIds = (await fixture.history.listHistory())
          .map((entry) => entry.id)
          .toList();

      const BackupRestorePreviewService().preview(jsonText);

      expect(await fixture.products.listProducts(), beforeProducts);
      expect(await fixture.inventory.listAllMovements(), beforeMovements);
      expect(await fixture.purchases.listPurchaseIntakes(), beforePurchases);
      expect(await fixture.sales.listSales(), beforeSales);
      expect(
        (await fixture.history.listHistory()).map((entry) => entry.id),
        beforeHistoryIds,
      );
    });
  });
}

Future<void> _setTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<Map<String, Object?>> _decodedBackup(_BackupFixture fixture) async {
  final result = await fixture.service.createBackup();
  return jsonDecode(result.jsonText) as Map<String, Object?>;
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
    now: () => DateTime.utc(2026, 7, 6, 15, 42, 30),
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
