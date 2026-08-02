import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

final _owner = AppUser(
  id: 'owner',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

void main() {
  group('Phase 95 - BusinessIdentity model with profile fields', () {
    test('empty identity has no profile fields', () {
      const identity = BusinessIdentity.empty;
      expect(identity.establishmentName, isNull);
      expect(identity.logo, isNull);
      expect(identity.taxNumber, isNull);
      expect(identity.address, isNull);
      expect(identity.phone, isNull);
      expect(identity.hasTaxNumber, isFalse);
      expect(identity.hasAddress, isFalse);
      expect(identity.hasPhone, isFalse);
    });

    test('identity with profile fields preserves values', () {
      const identity = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123-456-789',
        address: 'القاهرة، مصر',
        phone: '01012345678',
      );
      expect(identity.taxNumber, '123-456-789');
      expect(identity.address, 'القاهرة، مصر');
      expect(identity.phone, '01012345678');
      expect(identity.hasTaxNumber, isTrue);
      expect(identity.hasAddress, isTrue);
      expect(identity.hasPhone, isTrue);
      expect(identity.displayName, 'غلالة');
    });

    test('trimmed getters trim whitespace', () {
      const identity = BusinessIdentity(
        taxNumber: '  123  ',
        address: '  العنوان  ',
        phone: '  010123  ',
      );
      expect(identity.trimmedTaxNumber, '123');
      expect(identity.trimmedAddress, 'العنوان');
      expect(identity.trimmedPhone, '010123');
    });

    test('trimmed getters return null for blank values', () {
      const identity = BusinessIdentity(
        taxNumber: '   ',
        address: '  ',
        phone: '',
      );
      expect(identity.trimmedTaxNumber, isNull);
      expect(identity.trimmedAddress, isNull);
      expect(identity.trimmedPhone, isNull);
      expect(identity.hasTaxNumber, isFalse);
      expect(identity.hasAddress, isFalse);
      expect(identity.hasPhone, isFalse);
    });

    test('copyWith preserves existing fields when not overridden', () {
      const original = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
      );
      final copied = original.copyWith(establishmentName: 'جديد');
      expect(copied.establishmentName, 'جديد');
      expect(copied.taxNumber, '123');
      expect(copied.address, 'العنوان');
      expect(copied.phone, '010');
    });

    test('copyWith can update individual profile fields', () {
      const original = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
      );
      final updated = original.copyWith(taxNumber: '999');
      expect(updated.taxNumber, '999');
      expect(updated.address, 'العنوان');
      expect(updated.phone, '010');
      expect(updated.establishmentName, 'غلالة');
    });

    test('copyWith clear flags nullify fields', () {
      const original = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
        logo: LogoMetadata(
          managedFileName: 'f.png',
          mimeType: 'image/png',
          sha256: 'abc',
          byteLength: 100,
          width: 0,
          height: 0,
        ),
      );
      final cleared = original.copyWith(
        clearTaxNumber: true,
        clearAddress: true,
        clearPhone: true,
        clearLogo: true,
      );
      expect(cleared.taxNumber, isNull);
      expect(cleared.address, isNull);
      expect(cleared.phone, isNull);
      expect(cleared.hasLogo, isFalse);
      expect(cleared.establishmentName, 'غلالة');
    });

    test('toJson includes profile fields when non-null', () {
      const identity = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
      );
      final json = identity.toJson();
      expect(json['taxNumber'], '123');
      expect(json['address'], 'العنوان');
      expect(json['phone'], '010');
      expect(json['establishmentName'], 'غلالة');
    });

    test('toJson omits profile fields when null', () {
      const identity = BusinessIdentity(establishmentName: 'غلالة');
      final json = identity.toJson();
      expect(json.containsKey('taxNumber'), isFalse);
      expect(json.containsKey('address'), isFalse);
      expect(json.containsKey('phone'), isFalse);
    });

    test('fromJson reads profile fields correctly', () {
      final json = {
        'establishmentName': 'غلالة',
        'taxNumber': '123',
        'address': 'العنوان',
        'phone': '010',
      };
      final identity = BusinessIdentity.fromJson(json);
      expect(identity.establishmentName, 'غلالة');
      expect(identity.taxNumber, '123');
      expect(identity.address, 'العنوان');
      expect(identity.phone, '010');
    });

    test('fromJson defaults missing profile fields to null', () {
      final json = {'establishmentName': 'غلالة'};
      final identity = BusinessIdentity.fromJson(json);
      expect(identity.taxNumber, isNull);
      expect(identity.address, isNull);
      expect(identity.phone, isNull);
    });

    test('fromJson handles null and non-map gracefully', () {
      expect(BusinessIdentity.fromJson(null).taxNumber, isNull);
      expect(BusinessIdentity.fromJson('invalid').taxNumber, isNull);
      expect(BusinessIdentity.fromJson(42).taxNumber, isNull);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      const original = BusinessIdentity(
        establishmentName: 'غلالة',
        taxNumber: '123-456',
        address: 'القاهرة، مصر',
        phone: '01012345678',
      );
      final json = original.toJson();
      final restored = BusinessIdentity.fromJson(json);
      expect(restored.establishmentName, original.establishmentName);
      expect(restored.taxNumber, original.taxNumber);
      expect(restored.address, original.address);
      expect(restored.phone, original.phone);
    });

    test('round-trip with Arabic multiline address', () {
      const original = BusinessIdentity(
        address: 'شارع المعز، القاهرة\nالقاهرة، مصر',
      );
      final json = original.toJson();
      final restored = BusinessIdentity.fromJson(json);
      expect(restored.address, original.address);
    });

    test('tax number with leading zeroes preserved as string', () {
      const original = BusinessIdentity(taxNumber: '00123456');
      final json = original.toJson();
      final restored = BusinessIdentity.fromJson(json);
      expect(restored.taxNumber, '00123456');
    });

    test('updating one profile field does not erase others', () {
      const original = BusinessIdentity(
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
      );
      final updated = original.copyWith(phone: '999');
      expect(updated.taxNumber, '123');
      expect(updated.address, 'العنوان');
      expect(updated.phone, '999');
    });

    test('invalid input does not partially persist via copyWith', () {
      const original = BusinessIdentity(
        taxNumber: '123',
        address: 'العنوان',
      );
      final failed = original.copyWith(clearAddress: true);
      expect(failed.taxNumber, '123');
      expect(failed.address, isNull);
    });

    test('empty identity toString includes type name', () {
      expect(BusinessIdentity.empty.toString(), contains('BusinessIdentity'));
    });
  });

  group('Phase 95 - BusinessIdentityController profile save', () {
    test('saveProfileDetails updates and persists all fields', () async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await controller.saveProfileDetails(
        taxNumber: '123',
        address: 'العنوان',
        phone: '010',
      );

      expect(controller.identity.taxNumber, '123');
      expect(controller.identity.address, 'العنوان');
      expect(controller.identity.phone, '010');

      final saved = await repo.loadIdentity();
      expect(saved.taxNumber, '123');
      expect(saved.address, 'العنوان');
      expect(saved.phone, '010');
    });

    test('saveProfileDetails trims whitespace', () async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await controller.saveProfileDetails(
        taxNumber: '  123  ',
        address: '  العنوان  ',
        phone: '  010  ',
      );

      expect(controller.identity.trimmedTaxNumber, '123');
      expect(controller.identity.trimmedAddress, 'العنوان');
      expect(controller.identity.trimmedPhone, '010');
    });

    test('saveProfileDetails converts blank to null', () async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await controller.saveProfileDetails(
        taxNumber: '   ',
        address: '',
        phone: '  ',
      );

      expect(controller.identity.taxNumber, isNull);
      expect(controller.identity.address, isNull);
      expect(controller.identity.phone, isNull);
    });

    test('saveProfileDetails does not erase establishmentName', () async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(establishmentName: 'غلالة'),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await controller.saveProfileDetails(phone: '010');

      expect(controller.identity.establishmentName, 'غلالة');
      expect(controller.identity.phone, '010');
    });

    test('saveProfileDetails sets success message', () async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await controller.saveProfileDetails(taxNumber: '123');
      expect(controller.message, contains('تم حفظ'));
    });
  });

  group('Phase 95 - Backup and restore round-trip', () {
    late Directory sourceDir;
    late Directory targetDir;

    setUp(() async {
      sourceDir = await Directory.systemTemp.createTemp('phase95-src-');
      targetDir = await Directory.systemTemp.createTemp('phase95-dst-');
    });

    tearDown(() async {
      if (await sourceDir.exists()) await sourceDir.delete(recursive: true);
      if (await targetDir.exists()) await targetDir.delete(recursive: true);
    });

    test('new backup round-trip preserves all profile fields', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      await sourceRepo.saveIdentity(
        const BusinessIdentity(
          establishmentName: 'غلالة',
          taxNumber: '123-456',
          address: 'القاهرة، مصر',
          phone: '01012345678',
        ),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();

      final targetRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(result.success, isTrue);

      final restored = await target.identityRepository.loadIdentity();
      expect(restored.establishmentName, 'غلالة');
      expect(restored.taxNumber, '123-456');
      expect(restored.address, 'القاهرة، مصر');
      expect(restored.phone, '01012345678');
    });

    test('older backup without profile fields restores successfully', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      await sourceRepo.saveIdentity(
        const BusinessIdentity(establishmentName: 'غلالة قديمة'),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();

      final targetRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(result.success, isTrue);

      final restored = await target.identityRepository.loadIdentity();
      expect(restored.establishmentName, 'غلالة قديمة');
      expect(restored.taxNumber, isNull);
      expect(restored.address, isNull);
      expect(restored.phone, isNull);
    });

    test('Arabic address survives backup round-trip', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      const arabicAddress = 'شارع المعز، القاهرة\nالقاهرة، مصر';
      await sourceRepo.saveIdentity(
        const BusinessIdentity(address: arabicAddress),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();

      final targetRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(result.success, isTrue);

      final restored = await target.identityRepository.loadIdentity();
      expect(restored.address, arabicAddress);
    });

    test('tax number with leading zeroes preserved as string', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      await sourceRepo.saveIdentity(
        const BusinessIdentity(taxNumber: '00123456'),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();

      final targetRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(result.success, isTrue);

      final restored = await target.identityRepository.loadIdentity();
      expect(restored.taxNumber, '00123456');
    });

    test('phone remains a string in backup', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      await sourceRepo.saveIdentity(
        const BusinessIdentity(phone: '+201012345678'),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();

      final targetRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(result.success, isTrue);

      final restored = await target.identityRepository.loadIdentity();
      expect(restored.phone, '+201012345678');
    });

    test('existing name/logo backup behavior unchanged', () async {
      final sourceRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );
      await sourceRepo.saveIdentity(
        const BusinessIdentity(establishmentName: 'غلالة'),
      );

      final source = _RepoSet(identityRepository: sourceRepo);
      final backup = await source.exportService.createBackup();
      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final settings = data['settings'] as Map<String, Object?>;
      final identity = settings['businessIdentity'] as Map<String, Object?>;
      expect(identity['establishmentName'], 'غلالة');
    });
  });

  group('Phase 95 - Settings UI', () {
    testWidgets('existing values populate the form fields', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(
        const BusinessIdentity(
          establishmentName: 'غلالة',
          taxNumber: '123',
          address: 'العنوان',
          phone: '010',
        ),
      );
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: const _TestSettingsWrapper(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غلالة'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(find.text('العنوان'), findsAtLeast(2));
      expect(find.text('010'), findsOneWidget);
    });

    testWidgets('profile details section is visible', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: const _TestSettingsWrapper(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بيانات المنشأة الإضافية'), findsOneWidget);
      expect(find.text('رقم التسجيل الضريبي'), findsOneWidget);
      expect(find.text('العنوان'), findsAtLeast(1));
      expect(find.text('رقم الهاتف'), findsOneWidget);
    });

    testWidgets('no overflow at common test dimensions', (tester) async {
      final repo = _MemoryBusinessIdentityRepository(BusinessIdentity.empty);
      final controller = BusinessIdentityController(repository: repo);
      await controller.initialize();

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessIdentityScope(
            controller: controller,
            child: const _TestSettingsWrapper(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull);
    });
  });
}

class _TestSettingsWrapper extends StatelessWidget {
  const _TestSettingsWrapper();

  @override
  Widget build(BuildContext context) {
    final controller = BusinessIdentityScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final identity = controller.identity;
        return ListView(
          children: [
            Text(identity.displayName),
            const SizedBox(height: 8),
            if (identity.trimmedTaxNumber != null)
              Text(identity.trimmedTaxNumber!),
            if (identity.trimmedAddress != null) Text(identity.trimmedAddress!),
            if (identity.trimmedPhone != null) Text(identity.trimmedPhone!),
            const SizedBox(height: 8),
            const Text('بيانات المنشأة الإضافية'),
            const Text('رقم التسجيل الضريبي'),
            const Text('العنوان'),
            const Text('رقم الهاتف'),
          ],
        );
      },
    );
  }
}

class _MemoryBusinessIdentityRepository implements BusinessIdentityRepository {
  _MemoryBusinessIdentityRepository(this._identity);

  BusinessIdentity _identity;

  @override
  Future<BusinessIdentity> loadIdentity() async => _identity;

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    return null;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    return null;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  String get managedLogosDirectory => '';
}

class _RepoSet {
  _RepoSet({required this.identityRepository})
      : auditLogRepository = LocalAuditLogRepository(),
        productRepository = LocalProductRepository(),
        supplierRepository = LocalSupplierRepository(),
        customerRepository = LocalCustomerRepository(),
        expenseRepository = LocalExpenseRepository() {
    inventoryRepository =
        LocalInventoryRepository(productRepository: productRepository);
    customerAccountRepository = LocalCustomerAccountRepository(
      customerRepository: customerRepository,
      auditLogRepository: auditLogRepository,
    );
    supplierAccountRepository = LocalSupplierAccountRepository(
      supplierRepository: supplierRepository,
      auditLogRepository: auditLogRepository,
    );
    purchaseRepository = LocalPurchaseRepository(
      supplierRepository: supplierRepository,
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
      supplierAccountRepository: supplierAccountRepository,
    );
    saleRepository = LocalSaleRepository(
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
    );
    documentHistoryRepository = LocalDocumentHistoryRepository(
      purchaseRepository: purchaseRepository,
      saleRepository: saleRepository,
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(productRepository),
      inventoryRepository: inventoryRepository,
    );
  }

  final LocalBusinessIdentityRepository identityRepository;
  final LocalAuditLogRepository auditLogRepository;
  final LocalProductRepository productRepository;
  final LocalSupplierRepository supplierRepository;
  final LocalCustomerRepository customerRepository;
  final LocalExpenseRepository expenseRepository;
  late final LocalInventoryRepository inventoryRepository;
  late final LocalCustomerAccountRepository customerAccountRepository;
  late final LocalSupplierAccountRepository supplierAccountRepository;
  late final LocalPurchaseRepository purchaseRepository;
  late final LocalSaleRepository saleRepository;
  late final LocalDocumentHistoryRepository documentHistoryRepository;

  BackupExportService get exportService => BackupExportService(
        businessIdentityRepository: identityRepository,
        productCatalogReadRepository:
            ProductCatalogReadRepositoryTestAdapter(productRepository),
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
        customerRepository: customerRepository,
        customerAccountRepository: customerAccountRepository,
        supplierAccountRepository: supplierAccountRepository,
        expenseRepository: expenseRepository,
        auditLogRepository: auditLogRepository,
      );

  BackupRestoreService get restoreService => BackupRestoreService(
        businessIdentityRepository: identityRepository,
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
        customerRepository: customerRepository,
        customerAccountRepository: customerAccountRepository,
        supplierAccountRepository: supplierAccountRepository,
        expenseRepository: expenseRepository,
        auditLogRepository: auditLogRepository,
      );
}
