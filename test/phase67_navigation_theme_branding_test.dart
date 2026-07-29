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
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/features/help/help_guide_screen.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 67 - navigation, theme, and branding', () {
    testWidgets('sub-page has Arabic back control and maybePop is safe',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HelpGuideScreen(),
                  ),
                );
              },
              child: const Text('فتح الدليل'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح الدليل'));
      await tester.pumpAndSettle();

      expect(find.text('دليل الاستخدام'), findsWidgets);
      expect(find.byTooltip('رجوع'), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.text('فتح الدليل'), findsOneWidget);
    });

    test('theme labels are owner-safe and selected preset persists', () async {
      final dir = await Directory.systemTemp.createTemp('phase67-theme-');
      addTearDown(() => dir.delete(recursive: true));
      final themeController = ThemeController(
        repository: LocalThemeSettingsRepository(
          filePath: '${dir.path}${Platform.pathSeparator}theme.txt',
        ),
      );
      await themeController.initialize();

      expect(
          AppThemePreset.values.map((preset) => preset.labelAr),
          containsAll(
            ['اللون الافتراضي', 'أزرق', 'بني / قمح', 'داكن بسيط'],
          ));

      await themeController.selectPreset(AppThemePreset.blue);

      final reloaded = await LocalThemeSettingsRepository(
        filePath: '${dir.path}${Platform.pathSeparator}theme.txt',
      ).loadThemePreset();
      expect(reloaded.id, AppThemePreset.blue.id);
      expect(AppTheme.fromPreset(AppThemePreset.blue).colorScheme.error,
          isNot(AppThemePreset.blue.seed));
    });

    testWidgets('establishment name appears on invoices without changing total',
        (tester) async {
      final identityController = BusinessIdentityController(
        repository: _MemoryBusinessIdentityRepository(
          const BusinessIdentity(establishmentName: 'شركة الغلال الحديثة'),
        ),
      );
      addTearDown(identityController.dispose);
      await identityController.initialize();

      final sale = SaleRecord(
        id: 'SALE-67',
        productId: 'p1',
        quantityKg: 100,
        salePriceQirshPerKg: 700,
        totalQirsh: 70000,
        createdByUserId: 'owner',
        createdAt: DateTime(2026, 7, 10, 10),
        stockMovementId: 'sm-67',
        customerId: 'c1',
      );

      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: identityController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل',
                productNames: const {'p1': 'قمح'},
              ),
            ),
          ),
        ),
      );

      expect(find.text('شركة الغلال الحديثة'), findsOneWidget);
      expect(find.textContaining('700.00'), findsWidgets);
      expect(sale.totalQirsh, 70000);
    });

    test('backup export and empty restore preserve establishment name',
        () async {
      final sourceDir = await Directory.systemTemp.createTemp('phase67-src-');
      final targetDir = await Directory.systemTemp.createTemp('phase67-dst-');
      addTearDown(() => sourceDir.delete(recursive: true));
      addTearDown(() => targetDir.delete(recursive: true));

      final sourceIdentityRepository = LocalBusinessIdentityRepository(
        filePath:
            '${sourceDir.path}${Platform.pathSeparator}business_identity.json',
      );
      await sourceIdentityRepository.saveIdentity(
        const BusinessIdentity(establishmentName: 'مخزن اختبار الغلال'),
      );
      final source = _RepoSet(identityRepository: sourceIdentityRepository);
      final backup = await source.exportService.createBackup();
      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final settings = data['settings'] as Map<String, Object?>;
      final identity = settings['businessIdentity'] as Map<String, Object?>;
      expect(identity['establishmentName'], 'مخزن اختبار الغلال');

      final targetIdentityRepository = LocalBusinessIdentityRepository(
        filePath:
            '${targetDir.path}${Platform.pathSeparator}business_identity.json',
      );
      final target = _RepoSet(identityRepository: targetIdentityRepository);
      final now = DateTime(2026, 7, 10);
      final result = await target.restoreService.restoreToEmpty(
        user: AppUser(
          id: 'owner',
          name: 'المالك',
          phone: '01000000000',
          role: UserRole.owner,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        jsonText: backup.jsonText,
      );

      expect(result.success, isTrue);
      final restored = await targetIdentityRepository.loadIdentity();
      expect(restored.displayName, 'مخزن اختبار الغلال');
    });
  });
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
