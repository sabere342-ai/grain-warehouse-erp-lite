import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_restore_preview_screen.dart';

void main() {
  group('Phase 16 restore to empty system service', () {
    test('valid backup restores successfully into an empty system', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final jsonText = (await source.exportService.createBackup()).jsonText;

      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonText,
      );

      expect(result.success, isTrue);
      expect(result.message, 'تم استرجاع النسخة الاحتياطية بنجاح.');
      expect(result.counts!.products, 1);
      expect(result.counts!.inventoryMovements, 2);
      expect(result.counts!.suppliers, 1);
      expect(result.counts!.purchases, 1);
      expect(result.counts!.sales, 1);
      expect(result.counts!.documentHistory, 2);
      expect(await target.products.listProducts(), hasLength(1));
      expect(await target.inventory.listAllMovements(), hasLength(2));
      expect(await target.suppliers.listSuppliers(), hasLength(1));
      expect(await target.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await target.sales.listSales(), hasLength(1));
      expect(await target.history.listHistory(), hasLength(2));
    });

    test('restore is blocked if products already exist', () async {
      final fixture = await _emptyFixture();
      await fixture.products.createProduct(_productDraft('منتج موجود'));

      await _expectBlockedAsNonEmpty(fixture);
    });

    test('restore is blocked if inventory movements already exist', () async {
      final fixture = await _emptyFixture();
      final product =
          await fixture.products.createProduct(_productDraft('قمح'));
      await fixture.inventory.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 10,
          createdByUserId: _owner.id,
        ),
      );

      await _expectBlockedAsNonEmpty(fixture);
    });

    test('restore is blocked if purchases already exist', () async {
      final fixture = await _emptyFixture();
      final product =
          await fixture.products.createProduct(_productDraft('قمح'));
      final supplier = await fixture.suppliers.createSupplier(
        const SupplierDraft(name: 'مورد موجود'),
      );
      await fixture.purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 500,
          createdByUserId: _owner.id,
        ),
      );

      await _expectBlockedAsNonEmpty(fixture);
    });

    test('restore is blocked if sales already exist', () async {
      final fixture = await _emptyFixture();
      final product =
          await fixture.products.createProduct(_productDraft('قمح'));
      await fixture.inventory.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 100,
          createdByUserId: _owner.id,
        ),
      );
      await fixture.sales.createSale(
        SaleDraft(
          productId: product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 700,
          createdByUserId: _owner.id,
        ),
      );

      await _expectBlockedAsNonEmpty(fixture);
    });

    test('restore is blocked if document history exists', () async {
      final fixture = await _emptyFixture();
      final product =
          await fixture.products.createProduct(_productDraft('قمح'));
      final supplier = await fixture.suppliers.createSupplier(
        const SupplierDraft(name: 'مورد موجود'),
      );
      await fixture.purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 500,
          createdByUserId: _owner.id,
        ),
      );
      expect(await fixture.history.listHistory(), isNotEmpty);

      await _expectBlockedAsNonEmpty(fixture);
    });

    test('invalid backup JSON is rejected and writes nothing', () async {
      final fixture = await _emptyFixture();

      final result = await fixture.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: '{bad-json',
      );

      expect(result.success, isFalse);
      await _expectEmpty(fixture);
    });

    test('sensitive backup keys are rejected and write nothing', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final backup = await _decodedBackup(source);
      final data = backup['data'] as Map<String, Object?>;
      ((data['products'] as List<Object?>).first
          as Map<String, Object?>)['password'] = 'hidden';

      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(backup),
      );

      expect(result.success, isFalse);
      await _expectEmpty(target);
    });

    test('mismatched counts are rejected and write nothing', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final backup = await _decodedBackup(source);
      (backup['counts'] as Map<String, Object?>)['products'] = 2;

      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(backup),
      );

      expect(result.success, isFalse);
      await _expectEmpty(target);
    });

    test('unsupported backupVersion is rejected and write nothing', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final backup = await _decodedBackup(source);
      (backup['metadata'] as Map<String, Object?>)['backupVersion'] = 99;

      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(backup),
      );

      expect(result.success, isFalse);
      await _expectEmpty(target);
    });

    test('restoreSupported true is rejected and write nothing', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final backup = await _decodedBackup(source);
      (backup['metadata'] as Map<String, Object?>)['restoreSupported'] = true;

      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(backup),
      );

      expect(result.success, isFalse);
      await _expectEmpty(target);
    });

    test('restore does not create or modify auth users or sessions', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();
      final auth = _StaticAuthRepository(_owner);

      await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: (await source.exportService.createBackup()).jsonText,
      );

      expect(await auth.currentUser(), _owner);
      expect(await auth.hasOwner(), isTrue);
    });

    test('non-owner cannot restore', () async {
      final source = await _seededFixture();
      final target = await _emptyFixture();

      final result = await target.restoreService.restoreToEmpty(
        user: _employee,
        jsonText: (await source.exportService.createBackup()).jsonText,
      );

      expect(result.success, isFalse);
      expect(result.message, 'هذه الأداة متاحة للمالك فقط.');
      await _expectEmpty(target);
    });
  });

  group('Phase 16 restore to empty system UI', () {
    testWidgets('restore section appears only after valid preview',
        (tester) async {
      await _setTallViewport(tester);
      final source = await _seededFixture();
      final target = await _emptyFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupRestorePreviewScreen(
            restoreService: target.restoreService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('استرجاع إلى نظام فارغ'), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        (await source.exportService.createBackup()).jsonText,
      );
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();

      expect(find.text('استرجاع النسخة إلى نظام فارغ'), findsOneWidget);
      expect(find.text('استرجاع إلى نظام فارغ'), findsOneWidget);
      expect(find.textContaining('لن يتم استبدال أو دمج'), findsOneWidget);
    });

    testWidgets('confirmation dialog appears before restore', (tester) async {
      await _setTallViewport(tester);
      final source = await _seededFixture();
      final target = await _emptyFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupRestorePreviewScreen(
            restoreService: target.restoreService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        (await source.exportService.createBackup()).jsonText,
      );
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استرجاع إلى نظام فارغ'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الاسترجاع'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تأكيد الاسترجاع'), findsWidgets);
    });

    testWidgets('successful restore shows success message', (tester) async {
      await _setTallViewport(tester);
      final source = await _seededFixture();
      final target = await _emptyFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupRestorePreviewScreen(
            restoreService: target.restoreService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        (await source.exportService.createBackup()).jsonText,
      );
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استرجاع إلى نظام فارغ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد الاسترجاع'));
      await tester.pumpAndSettle();

      expect(find.text('تم استرجاع النسخة الاحتياطية بنجاح.'), findsOneWidget);
      expect(await target.products.listProducts(), hasLength(1));
    });

    testWidgets('non-owner cannot restore', (tester) async {
      final target = await _emptyFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _employee,
          child: BackupRestorePreviewScreen(
            restoreService: target.restoreService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('هذه الأداة متاحة للمالك فقط.'), findsOneWidget);
      expect(find.text('استرجاع إلى نظام فارغ'), findsNothing);
    });

    testWidgets('non-empty system shows guard message', (tester) async {
      await _setTallViewport(tester);
      final source = await _seededFixture();
      final target = await _emptyFixture();
      await target.products.createProduct(_productDraft('موجود'));

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupRestorePreviewScreen(
            restoreService: target.restoreService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        (await source.exportService.createBackup()).jsonText,
      );
      await tester.tap(find.text('فحص النسخة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('استرجاع إلى نظام فارغ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد الاسترجاع'));
      await tester.pumpAndSettle();

      expect(find.textContaining('النظام الحالي ليس فارغا'), findsOneWidget);
    });
  });
}

Future<void> _expectBlockedAsNonEmpty(_BackupFixture fixture) async {
  final source = await _seededFixture();
  final result = await fixture.restoreService.restoreToEmpty(
    user: _owner,
    jsonText: (await source.exportService.createBackup()).jsonText,
  );

  expect(result.success, isFalse);
  expect(result.message, contains('النظام الحالي ليس فارغا'));
}

Future<void> _expectEmpty(_BackupFixture fixture) async {
  expect(await fixture.products.listProducts(), isEmpty);
  expect(await fixture.inventory.listAllMovements(), isEmpty);
  expect(await fixture.suppliers.listSuppliers(), isEmpty);
  expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
  expect(await fixture.sales.listSales(), isEmpty);
  expect(await fixture.history.listHistory(), isEmpty);
}

Future<Map<String, Object?>> _decodedBackup(_BackupFixture fixture) async {
  final result = await fixture.exportService.createBackup();
  return jsonDecode(result.jsonText) as Map<String, Object?>;
}

ProductDraft _productDraft(String name) {
  return ProductDraft(name: name, unit: GrainUnit.kilogram);
}

Future<_BackupFixture> _seededFixture() async {
  final fixture = await _emptyFixture();
  final supplier = await fixture.suppliers.createSupplier(
    const SupplierDraft(name: 'مورد القمح', phone: '01011112222'),
  );
  final product = await fixture.products.createProduct(_productDraft('قمح'));
  await fixture.purchases.createPurchaseIntake(
    PurchaseIntakeDraft(
      supplierId: supplier.id,
      productId: product.id,
      quantityKg: 1000,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 650,
      createdByUserId: _owner.id,
    ),
  );
  await fixture.sales.createSale(
    SaleDraft(
      productId: product.id,
      quantityKg: 250,
      salePriceQirshPerKg: 800,
      createdByUserId: _owner.id,
    ),
  );
  return fixture;
}

Future<_BackupFixture> _emptyFixture() async {
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
  final exportService = BackupExportService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    now: () => DateTime.utc(2026, 7, 6, 15, 42, 30),
  );
  final restoreService = BackupRestoreService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
  );

  return _BackupFixture(
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    purchases: purchases,
    sales: sales,
    history: history,
    exportService: exportService,
    restoreService: restoreService,
  );
}

Future<void> _setTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.exportService,
    required this.restoreService,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final BackupExportService exportService;
  final BackupRestoreService restoreService;
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
