import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
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

void main() {
  group('Phase 14 backup file save and hardening', () {
    testWidgets('backup screen exposes copy and file save actions',
        (tester) async {
      final fixture = await _fixture();
      final writer = _FakeBackupFileWriter();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(
            service: fixture.service,
            fileWriter: writer,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('النسخ الاحتياطي'), findsOneWidget);
      expect(find.text('إنشاء نسخة احتياطية'), findsOneWidget);
      expect(find.textContaining('الاسترجاع متاح فقط إلى نظام فارغ'), findsOneWidget);

      await tester.tap(find.text('إنشاء نسخة احتياطية'));
      await tester.pumpAndSettle();

      expect(find.text('نسخ بيانات النسخة'), findsOneWidget);
      expect(find.text('حفظ النسخة في ملف'), findsOneWidget);
    });

    test('export snapshot remains compatible with phase 13 shape', () async {
      final fixture = await _fixture();

      final result = await fixture.service.createBackup();
      final decoded = jsonDecode(result.jsonText) as Map<String, Object?>;
      final metadata = decoded['metadata'] as Map<String, Object?>;

      expect(decoded, containsPair('metadata', isA<Map<String, Object?>>()));
      expect(decoded, containsPair('counts', isA<Map<String, Object?>>()));
      expect(decoded, containsPair('data', isA<Map<String, Object?>>()));
      expect(metadata['restoreSupported'], isFalse);
      expect(metadata['backupVersion'], 1);
      expect(metadata['fileName'], result.fileName);
    });

    test('filename helper produces a safe json filename', () {
      final fileName = BackupFileName.forGeneratedAt(
        DateTime(2026, 7, 6, 15, 42, 30),
      );

      expect(fileName, startsWith('grain-warehouse-backup-'));
      expect(fileName, endsWith('.json'));
      expect(fileName, 'grain-warehouse-backup-20260706-154230.json');
      expect(BackupFileName.isSafeWindowsFileName(fileName), isTrue);
      expect(RegExp(r'[<>:"/\\|?*\s]').hasMatch(fileName), isFalse);
    });

    test('export validation rejects sensitive keys', () {
      for (final key in [
        'password',
        'passwordHash',
        'token',
        'session',
        'secret',
      ]) {
        final jsonText = jsonEncode({
          'metadata': {
            'restoreSupported': false,
          },
          'counts': <String, int>{},
          'data': {
            'products': [
              {key: 'hidden'},
            ],
          },
        });

        expect(
          () => BackupExportValidator.validateJsonText(jsonText),
          throwsA(isA<BackupExportValidationException>()),
          reason: 'Expected $key to be rejected',
        );
      }
    });

    testWidgets('file save writes backup through injected writer',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _fixture();
      final writer = _FakeBackupFileWriter();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(
            service: fixture.service,
            fileWriter: writer,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('إنشاء نسخة احتياطية'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('حفظ النسخة في ملف'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('حفظ النسخة في ملف'));
      await tester.pumpAndSettle();

      expect(writer.savedFileName, startsWith('grain-warehouse-backup-'));
      expect(writer.savedFileName, endsWith('.json'));
      expect(jsonDecode(writer.savedJsonText!), isA<Map<String, Object?>>());
      expect(find.text('تم حفظ النسخة الاحتياطية بنجاح.'), findsWidgets);
      expect(find.text('اسم الملف'), findsOneWidget);
      expect(find.text('مكان الحفظ'), findsOneWidget);
    });

    test('export and save do not mutate business repositories', () async {
      final fixture = await _fixture();
      final beforeProducts = await fixture.products.listProducts();
      final beforeMovements = await fixture.inventory.listAllMovements();
      final beforePurchases = await fixture.purchases.listPurchaseIntakes();
      final beforeSales = await fixture.sales.listSales();
      final beforeHistoryIds = (await fixture.history.listHistory())
          .map((entry) => entry.id)
          .toList();
      final writer = _FakeBackupFileWriter();

      final result = await fixture.service.createBackup();
      await writer.save(fileName: result.fileName, jsonText: result.jsonText);

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
  await sales.createSale(
    SaleDraft(
      productId: product.id,
      quantityKg: 250,
      salePriceQirshPerKg: 800,
      createdByUserId: _owner.id,
    ),
  );

  final service = BackupExportService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    now: () => DateTime(2026, 7, 6, 15, 42, 30),
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

class _FakeBackupFileWriter implements BackupFileWriter {
  String? savedFileName;
  String? savedJsonText;

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async {
    savedFileName = fileName;
    savedJsonText = jsonText;
    return BackupFileSaveResult(
      fileName: fileName,
      filePath: 'C:\\fake-backups\\$fileName',
      folderPath: 'C:\\fake-backups',
    );
  }
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
