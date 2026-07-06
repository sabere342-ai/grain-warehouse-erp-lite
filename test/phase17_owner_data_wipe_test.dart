import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
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
import 'package:grain_warehouse_erp_lite/features/backup/data_wipe_screen.dart';

const _ownerOnly =
    '\u0647\u0630\u0647 \u0627\u0644\u0623\u062f\u0627\u0629 \u0645\u062a\u0627\u062d\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637.';
const _wrongConfirmation =
    '\u0627\u0643\u062a\u0628 \u0639\u0628\u0627\u0631\u0629 \u0627\u0644\u062a\u0623\u0643\u064a\u062f \u0643\u0645\u0627 \u0647\u064a \u0644\u0644\u0645\u062a\u0627\u0628\u0639\u0629.';
const _noDeletion =
    '\u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u0623\u064a \u0628\u064a\u0627\u0646\u0627\u062a';
const _wipeSuccess =
    '\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u062b\u0645 \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0628\u0646\u062c\u0627\u062d.';
const _dangerSection =
    '\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u062e\u0637\u064a\u0631\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637';
const _dangerLabel = '\u0625\u062c\u0631\u0627\u0621 \u062e\u0637\u064a\u0631';
const _wipeOperatingData =
    '\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644';
const _backupFirst =
    '\u0633\u064a\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0623\u0648\u0644\u0627.';
const _ownerNotDeleted =
    '\u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0623\u0648 \u0628\u064a\u0627\u0646\u0627\u062a \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644.';
const _confirmWipeTitle =
    '\u062a\u0623\u0643\u064a\u062f \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644';
const _continue = '\u0645\u062a\u0627\u0628\u0639\u0629';
const _cancel = '\u0625\u0644\u063a\u0627\u0621';
const _finalWipeButton =
    '\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0628\u0639\u062f \u0627\u0644\u0646\u0633\u062e \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a';

void main() {
  group('Phase 17 owner data wipe service', () {
    test('owner can wipe operational data only after successful backup save',
        () async {
      final fixture = await _seededFixture();
      final result = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isTrue);
      expect(fixture.fileWriter.saveCalls, 1);
      expect(result.backupSaveResult!.fileName, isNotEmpty);
      expect(result.backupSaveResult!.folderPath, 'C:\\safe-backups');
      expect(result.message, _wipeSuccess);
      await _expectEmptyOperationalData(fixture);
    });

    test('wipe deletes every operational category and reports counts',
        () async {
      final fixture = await _seededFixture();
      final result = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.wipedCounts!.products, 1);
      expect(result.wipedCounts!.inventoryMovements, 2);
      expect(result.wipedCounts!.suppliers, 1);
      expect(result.wipedCounts!.purchases, 1);
      expect(result.wipedCounts!.sales, 1);
      expect(result.wipedCounts!.documentHistory, 2);
      await _expectEmptyOperationalData(fixture);
    });

    test('owner auth/session remains available after wipe', () async {
      final fixture = await _seededFixture();
      final auth = _StaticAuthRepository(_owner);

      await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(await auth.currentUser(), _owner);
      expect(await auth.hasOwner(), isTrue);
    });

    test('wipe is blocked if backup export fails and deletes nothing',
        () async {
      final fixture = await _seededFixture(exportFails: true);

      final result = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isFalse);
      expect(result.message, contains(_noDeletion));
      expect(fixture.fileWriter.saveCalls, 0);
      await _expectSeededOperationalData(fixture);
    });

    test('wipe is blocked if backup file save fails and deletes nothing',
        () async {
      final fixture = await _seededFixture(saveFails: true);

      final result = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isFalse);
      expect(result.message, contains(_noDeletion));
      expect(fixture.fileWriter.saveCalls, 1);
      await _expectSeededOperationalData(fixture);
    });

    test('wipe is blocked for non-owner', () async {
      final fixture = await _seededFixture();

      final result = await fixture.wipeService.wipeBusinessData(
        user: _employee,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );

      expect(result.success, isFalse);
      expect(result.message, _ownerOnly);
      expect(fixture.fileWriter.saveCalls, 0);
      await _expectSeededOperationalData(fixture);
    });

    test('wipe is blocked if typed confirmation is missing or wrong', () async {
      final fixture = await _seededFixture();

      final missing = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: '',
      );
      final wrong = await fixture.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: 'wrong phrase',
      );

      expect(missing.success, isFalse);
      expect(wrong.success, isFalse);
      expect(wrong.message, _wrongConfirmation);
      expect(fixture.fileWriter.saveCalls, 0);
      await _expectSeededOperationalData(fixture);
    });

    test('after wipe restore-to-empty service accepts a valid backup',
        () async {
      final source = await _seededFixture();
      final target = await _seededFixture();
      final backupJson = (await source.exportService.createBackup()).jsonText;

      await target.wipeService.wipeBusinessData(
        user: _owner,
        confirmationText: BusinessDataWipeService.confirmationPhrase,
      );
      final restore = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backupJson,
      );

      expect(restore.success, isTrue);
      expect(await target.products.listProducts(), hasLength(1));
    });
  });

  group('Phase 17 owner data wipe UI', () {
    testWidgets('owner sees dangerous action entry on backup screen',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: BackupExportScreen(wipeService: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_dangerSection), findsOneWidget);
      expect(find.text(_dangerLabel), findsOneWidget);
      expect(find.text(_wipeOperatingData), findsOneWidget);
    });

    testWidgets('employee does not see dangerous action entry', (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _employee,
          child: BackupExportScreen(wipeService: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_ownerOnly), findsNothing);
      expect(find.text(_wipeOperatingData), findsNothing);
    });

    testWidgets('data wipe screen explains mandatory backup and owner safety',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_dangerLabel), findsOneWidget);
      expect(find.text(_backupFirst), findsOneWidget);
      expect(find.text(_ownerNotDeleted), findsOneWidget);
    });

    testWidgets('employee sees owner-only warning on data wipe screen',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _employee,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_ownerOnly), findsOneWidget);
      expect(find.text(_dangerLabel), findsNothing);
    });

    testWidgets('confirmation dialog appears before typed confirmation',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();
      await _tapContinue(tester);
      await tester.pumpAndSettle();

      expect(find.text(_confirmWipeTitle), findsOneWidget);
      expect(find.text(_cancel), findsOneWidget);
      expect(find.widgetWithText(FilledButton, _continue), findsWidgets);
    });

    testWidgets('final wipe button requires exact confirmation phrase',
        (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();
      await _tapContinue(tester);
      await tester.pumpAndSettle();
      await _tapDialogContinue(tester);
      await tester.pumpAndSettle();

      expect(find.text(_finalWipeButton), findsOneWidget);
      await tester.tap(find.text(_finalWipeButton));
      await tester.pumpAndSettle();
      expect(fixture.fileWriter.saveCalls, 0);

      await tester.enterText(find.byType(TextField), 'wrong phrase');
      await tester.pumpAndSettle();
      await tester.tap(find.text(_finalWipeButton));
      await tester.pumpAndSettle();
      expect(fixture.fileWriter.saveCalls, 0);

      await tester.enterText(
        find.byType(TextField),
        BusinessDataWipeService.confirmationPhrase,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_finalWipeButton));
      await tester.pumpAndSettle();
      expect(fixture.fileWriter.saveCalls, 1);
    });

    testWidgets('successful wipe shows success message', (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture();

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();
      await _acceptWarningAndEnterConfirmation(tester);
      await tester.tap(find.text(_finalWipeButton));
      await tester.pumpAndSettle();

      expect(find.text(_wipeSuccess), findsOneWidget);
      await _expectEmptyOperationalData(fixture);
    });

    testWidgets('backup failure shows no-deletion message', (tester) async {
      await _setTallViewport(tester);
      final fixture = await _seededFixture(saveFails: true);

      await tester.pumpWidget(
        _screenHarness(
          user: _owner,
          child: DataWipeScreen(service: fixture.wipeService),
        ),
      );
      await tester.pumpAndSettle();
      await _acceptWarningAndEnterConfirmation(tester);
      await tester.tap(find.text(_finalWipeButton));
      await tester.pumpAndSettle();

      expect(find.textContaining(_noDeletion), findsOneWidget);
      await _expectSeededOperationalData(fixture);
    });
  });
}

Future<void> _tapContinue(WidgetTester tester) async {
  final finder = find.text(_continue).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _tapDialogContinue(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(_continue),
    ),
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

Future<void> _acceptWarningAndEnterConfirmation(WidgetTester tester) async {
  await _tapContinue(tester);
  await tester.pumpAndSettle();
  await _tapDialogContinue(tester);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField),
    BusinessDataWipeService.confirmationPhrase,
  );
  await tester.pumpAndSettle();
}

Future<void> _expectSeededOperationalData(_BackupFixture fixture) async {
  expect(await fixture.products.listProducts(), hasLength(1));
  expect(await fixture.inventory.listAllMovements(), hasLength(2));
  expect(await fixture.suppliers.listSuppliers(), hasLength(1));
  expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
  expect(await fixture.sales.listSales(), hasLength(1));
  expect(await fixture.history.listHistory(), hasLength(2));
}

Future<void> _expectEmptyOperationalData(_BackupFixture fixture) async {
  expect(await fixture.products.listProducts(), isEmpty);
  expect(await fixture.inventory.listAllMovements(), isEmpty);
  expect(await fixture.suppliers.listSuppliers(), isEmpty);
  expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
  expect(await fixture.sales.listSales(), isEmpty);
  expect(await fixture.history.listHistory(), isEmpty);
}

ProductDraft _productDraft(String name) {
  return ProductDraft(name: name, unit: GrainUnit.kilogram);
}

Future<_BackupFixture> _seededFixture({
  bool exportFails = false,
  bool saveFails = false,
}) async {
  final fixture = await _emptyFixture(
    exportFails: exportFails,
    saveFails: saveFails,
  );
  final supplier = await fixture.suppliers.createSupplier(
    const SupplierDraft(name: 'supplier', phone: '01011112222'),
  );
  final product = await fixture.products.createProduct(_productDraft('wheat'));
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

Future<_BackupFixture> _emptyFixture({
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
    productRepository: products,
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
          now: () => DateTime.utc(2026, 7, 6, 15, 42, 30),
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
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.exportService,
    required this.fileWriter,
    required this.wipeService,
    required this.restoreService,
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
}

class _FakeBackupFileWriter implements BackupFileWriter {
  _FakeBackupFileWriter({this.throwsOnSave = false});

  final bool throwsOnSave;
  int saveCalls = 0;

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async {
    saveCalls++;
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
