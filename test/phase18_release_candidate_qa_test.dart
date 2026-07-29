import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/permissions.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
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
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_restore_preview_screen.dart';
import 'package:grain_warehouse_erp_lite/features/backup/data_wipe_screen.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

const _backupTitle =
    '\u0627\u0644\u0646\u0633\u062e \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a';
const _restorePreviewTitle =
    '\u0641\u062d\u0635 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629';
const _wipeTitle =
    '\u0625\u0639\u0627\u062f\u0629 \u062a\u0647\u064a\u0626\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u062e\u0632\u0646';
const _dangerLabel = '\u0625\u062c\u0631\u0627\u0621 \u062e\u0637\u064a\u0631';
const _backupFirst =
    '\u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0623\u0648\u0644\u0627.';
const _ownerNotDeleted =
    '\u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0623\u0648 \u0628\u064a\u0627\u0646\u0627\u062a \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644.';

void main() {
  group('Phase 18 release candidate lifecycle QA', () {
    test('business-day data can export, wipe, restore, and continue safely',
        () async {
      final fixture = await _seededBusinessDayFixture();

      expect(await fixture.inventory.currentStockKg(fixture.productId), 1000);
      expect(await fixture.inventory.listAllMovements(), hasLength(3));
      expect(await fixture.history.listHistory(), hasLength(2));
      expect(
        (await fixture.history.listHistory()).any((entry) => entry.isCancelled),
        isTrue,
      );

      final export = await fixture.exportService.createBackup();
      BackupExportValidator.validateJsonText(export.jsonText);
      final preview = const BackupRestorePreviewService().preview(
        export.jsonText,
      );
      expect(preview.isValid, isTrue);
      expect(preview.summary!.counts.products, 1);
      expect(preview.summary!.counts.inventoryMovements, 3);
      expect(preview.summary!.counts.documentHistory, 2);

      final wipe = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      expect(wipe.success, isTrue);
      expect(fixture.fileWriter.saveCalls, 1);
      await _expectEmptyOperationalData(fixture);

      final restore = await fixture.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: export.jsonText,
      );
      expect(restore.success, isTrue);
      expect(await fixture.products.listProducts(), hasLength(1));
      expect(await fixture.suppliers.listSuppliers(), hasLength(1));
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await fixture.sales.listSales(), hasLength(1));
      expect(await fixture.inventory.listAllMovements(), hasLength(3));
      expect(await fixture.history.listHistory(), hasLength(2));
      expect(await fixture.inventory.currentStockKg(fixture.productId), 1000);

      final restoreCustomer = await LocalCustomerRepository().createCustomer(
        const CustomerDraft(name: 'عميل', isActive: true),
      );
      await fixture.sales.createSale(
        SaleDraft(
          productId: fixture.productId,
          quantityKg: 100,
          salePriceQirshPerKg: 900,
          createdByUserId: _owner.id,
          customerId: restoreCustomer.id,
        ),
      );
      expect(await fixture.inventory.currentStockKg(fixture.productId), 900);
    });

    test('permissions keep owner-only RC operations protected', () async {
      expect(Permissions.owner.hasFullAccess, isTrue);
      expect(Permissions.owner.canExportBackups, isTrue);
      expect(Permissions.owner.canWipeBusinessData, isTrue);
      expect(Permissions.owner.canCancelInvoice, isTrue);
      expect(Permissions.owner.canViewReports, isTrue);

      expect(Permissions.employee.canCreateSale, isTrue);
      expect(Permissions.employee.canExportBackups, isFalse);
      expect(Permissions.employee.canWipeBusinessData, isFalse);
      expect(Permissions.employee.canCancelInvoice, isFalse);
      expect(Permissions.employee.canManageProducts, isFalse);
      expect(Permissions.employee.canCreateStockAdjustment, isFalse);
      expect(Permissions.employee.canViewAuditLogs, isFalse);
      expect(Permissions.employee.canApproveBelowMinimumPrice, isFalse);

      final fixture = await _seededBusinessDayFixture();
      final blocked = await fixture.wipeService.wipeBusinessData(
        user: _employee,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      expect(blocked.success, isFalse);
      expect(blocked.technicalReason, 'not-owner');
      expect(fixture.fileWriter.saveCalls, 0);
      await _expectSeededBusinessDayData(fixture);
    });

    test('dangerous wipe never deletes data unless backup and save succeed',
        () async {
      final wrongPhrase = await _seededBusinessDayFixture();
      final wrong = await wrongPhrase.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: 'wrong phrase',
      );
      expect(wrong.success, isFalse);
      expect(wrong.technicalReason, 'invalid-confirmation');
      expect(wrongPhrase.fileWriter.saveCalls, 0);
      await _expectSeededBusinessDayData(wrongPhrase);

      final exportFailure = await _seededBusinessDayFixture(exportFails: true);
      final failedExport = await exportFailure.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      expect(failedExport.success, isFalse);
      expect(failedExport.technicalReason, 'backup-required-failed');
      expect(exportFailure.fileWriter.saveCalls, 0);
      await _expectSeededBusinessDayData(exportFailure);

      final saveFailure = await _seededBusinessDayFixture(saveFails: true);
      final beforeMovements = await saveFailure.inventory.listAllMovements();
      final failedSave = await saveFailure.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      expect(failedSave.success, isFalse);
      expect(failedSave.technicalReason, 'backup-required-failed');
      expect(saveFailure.fileWriter.saveCalls, 1);
      expect(await saveFailure.inventory.listAllMovements(), beforeMovements);
      await _expectSeededBusinessDayData(saveFailure);
    });

    test('wipe creates no reversal or cancellation movements during deletion',
        () async {
      final fixture = await _seededBusinessDayFixture();
      final beforeTypes = (await fixture.inventory.listAllMovements())
          .map((movement) => movement.movementType)
          .toList();

      final result = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      final savedBackup =
          jsonDecode(fixture.fileWriter.savedJson!) as Map<String, Object?>;
      final counts = savedBackup['counts'] as Map<String, Object?>;

      expect(result.success, isTrue);
      expect(result.wipedCounts!.inventoryMovements, beforeTypes.length);
      expect(counts['inventoryMovements'], beforeTypes.length);
      expect(beforeTypes, <StockMovementType>[
        StockMovementType.purchaseIntake,
        StockMovementType.sale,
        StockMovementType.saleCancellation,
      ]);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
    });

    test('restore accepts valid backup only into an empty system', () async {
      final source = await _seededBusinessDayFixture();
      final target = await _emptyFixture(productId: source.productId);
      final jsonText = (await source.exportService.createBackup()).jsonText;

      final invalidPreview = const BackupRestorePreviewService().preview(
        '{bad-json',
      );
      expect(invalidPreview.isValid, isFalse);
      expect(invalidPreview.technicalReason, 'invalid-json');

      final restored = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonText,
      );
      expect(restored.success, isTrue);
      expect(await target.inventory.currentStockKg(source.productId), 1000);

      final nonEmptyTarget = await _seededBusinessDayFixture();
      final blocked = await nonEmptyTarget.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonText,
      );
      expect(blocked.success, isFalse);
      expect(blocked.technicalReason, 'system-not-empty');
      await _expectSeededBusinessDayData(nonEmptyTarget);
    });

    test('backup and restore do not create or mutate auth sessions', () async {
      final fixture = await _seededBusinessDayFixture();
      final auth = _StaticAuthRepository(_owner);
      final jsonText = (await fixture.exportService.createBackup()).jsonText;

      await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      await fixture.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: jsonText,
      );

      expect(await auth.currentUser(), _owner);
      expect(await auth.hasOwner(), isTrue);
      expect(
          (jsonDecode(jsonText) as Map<String, Object?>).containsKey('users'),
          isFalse);
    });
  });

  group('Phase 18 release candidate UI smoke QA', () {
    testWidgets(
        'backup, restore preview, and wipe screens keep Arabic RTL shell',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededBusinessDayWidgetFixture(tester);

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(
            service: fixture.exportService,
            wipeService: fixture.wipeService,
          ),
        ),
      );
      await _pumpExpectedState(tester);
      expect(Directionality.of(tester.element(find.text(_backupTitle))),
          TextDirection.rtl);
      expect(find.text(_backupTitle), findsOneWidget);

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupRestorePreviewScreen(
            restoreService: fixture.restoreService,
          ),
        ),
      );
      await _pumpExpectedState(tester);
      expect(find.text(_restorePreviewTitle), findsOneWidget);

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await _pumpExpectedState(tester);
      expect(find.text(_wipeTitle), findsOneWidget);
      expect(find.text(_dangerLabel), findsOneWidget);
      expect(find.text(_backupFirst), findsOneWidget);
      expect(find.text(_ownerNotDeleted), findsOneWidget);
    });
  });
}

Future<void> _expectSeededBusinessDayData(_BackupFixture fixture) async {
  expect(await fixture.products.listProducts(), hasLength(1));
  expect(await fixture.suppliers.listSuppliers(), hasLength(1));
  expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
  expect(await fixture.sales.listSales(), hasLength(1));
  expect(await fixture.inventory.listAllMovements(), hasLength(3));
  expect(await fixture.history.listHistory(), hasLength(2));
  expect(await fixture.inventory.currentStockKg(fixture.productId), 1000);
}

Future<void> _expectEmptyOperationalData(_BackupFixture fixture) async {
  expect(await fixture.products.listProducts(), isEmpty);
  expect(await fixture.suppliers.listSuppliers(), isEmpty);
  expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
  expect(await fixture.sales.listSales(), isEmpty);
  expect(await fixture.inventory.listAllMovements(), isEmpty);
  expect(await fixture.history.listHistory(), isEmpty);
}

Future<_BackupFixture> _seededBusinessDayFixture({
  bool exportFails = false,
  bool saveFails = false,
}) async {
  final fixture = await _emptyFixture(
    exportFails: exportFails,
    saveFails: saveFails,
  );
  final customers = LocalCustomerRepository();
  final customer = await customers.createCustomer(
    const CustomerDraft(name: 'عميل', isActive: true),
  );
  final supplier = await fixture.suppliers.createSupplier(
    const SupplierDraft(name: 'supplier', phone: '01011112222'),
  );
  final product = await fixture.products.createProduct(
    const ProductDraft(
      name: 'wheat',
      unit: GrainUnit.kilogram,
      defaultSalePricePiastersPerKg: 900,
      minimumSalePricePiastersPerKg: 700,
    ),
  );
  fixture.productId = product.id;
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
  final sale = await fixture.sales.createSale(
    SaleDraft(
      productId: product.id,
      quantityKg: 250,
      salePriceQirshPerKg: 800,
      createdByUserId: _owner.id,
      customerId: customer.id,
    ),
  );
  await fixture.sales.cancelSale(
    saleId: sale.id,
    cancelledByUserId: _owner.id,
    cancellationReason: 'qa cancellation',
  );
  return fixture;
}

Future<_BackupFixture> _seededBusinessDayWidgetFixture(
  WidgetTester tester,
) async {
  final fixture = await tester.runAsync(_seededBusinessDayFixture);
  if (fixture == null) {
    throw StateError('The widget fixture did not initialize.');
  }
  return fixture;
}

Future<_BackupFixture> _emptyFixture({
  String? productId,
  bool exportFails = false,
  bool saveFails = false,
}) async {
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
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
  );
  final exportService = exportFails
      ? _ThrowingBackupExportService(
          products: products,
          inventory: inventory,
          suppliers: suppliers,
          purchases: purchases,
          sales: sales,
          history: history,
        )
      : BackupExportService(
          productRepository: products,
          inventoryRepository: inventory,
          supplierRepository: suppliers,
          purchaseRepository: purchases,
          saleRepository: sales,
          documentHistoryRepository: history,
          now: () => DateTime.utc(2026, 7, 6, 12),
        );
  final fileWriter = _FakeBackupFileWriter(throwsOnSave: saveFails);
  final wipeService = BusinessDataWipeService(
    backupExportService: exportService,
    backupFileWriter: fileWriter,
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
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
    fileWriter: fileWriter,
    wipeService: wipeService,
    restoreService: restoreService,
    productId: productId ?? 'not-created-yet',
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
  addTearDown(controller.dispose);
  controller.initialize();
  return controller;
}

Future<void> _pumpExpectedState(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _BackupFixture {
  _BackupFixture({
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.exportService,
    required this.fileWriter,
    required this.wipeService,
    required this.restoreService,
    required this.productId,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final BackupExportService exportService;
  final _FakeBackupFileWriter fileWriter;
  final BusinessDataWipeService wipeService;
  final BackupRestoreService restoreService;
  String productId;
}

class _FakeBackupFileWriter implements BackupFileWriter {
  _FakeBackupFileWriter({this.throwsOnSave = false});

  final bool throwsOnSave;
  int saveCalls = 0;
  String? savedJson;

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async {
    saveCalls++;
    savedJson = jsonText;
    if (throwsOnSave) {
      throw StateError('Save failed.');
    }
    return BackupFileSaveResult(
      fileName: fileName,
      filePath: 'C:\\safe-backups\\$fileName',
      folderPath: 'C:\\safe-backups',
    );
  }
}

class _ThrowingBackupExportService extends BackupExportService {
  _ThrowingBackupExportService({
    required ProductRepository products,
    required InventoryRepository inventory,
    required SupplierRepository suppliers,
    required PurchaseRepository purchases,
    required SaleRepository sales,
    required DocumentHistoryRepository history,
  }) : super(
          productRepository: products,
          inventoryRepository: inventory,
          supplierRepository: suppliers,
          purchaseRepository: purchases,
          saleRepository: sales,
          documentHistoryRepository: history,
        );

  @override
  Future<BackupExportResult> createBackup() async {
    throw StateError('Backup export failed.');
  }
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
  name: 'owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

final _employee = AppUser(
  id: 'employee-test',
  name: 'employee',
  phone: '01100000000',
  role: UserRole.employee,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
