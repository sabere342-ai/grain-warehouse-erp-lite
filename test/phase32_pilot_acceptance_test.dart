import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 32 pilot owner acceptance QA', () {
    test('visible owner pages do not fall back to placeholder bodies', () {
      const visiblePageFiles = <String>[
        'lib/features/customers/customers_screen.dart',
        'lib/features/expenses/expenses_screen.dart',
        'lib/features/audit/audit_logs_screen.dart',
      ];

      for (final path in visiblePageFiles) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('PlaceholderFeatureScreen')));
        expect(source, isNot(contains('placeholder_feature_screen')));
      }

      final shell = File(
        'lib/features/dashboard/dashboard_shell.dart',
      ).readAsStringSync();
      expect(shell, contains('CustomersScreen'));
      expect(shell, contains('ExpensesScreen'));
      expect(shell, contains('AuditLogsScreen'));
      expect(shell, isNot(contains('PlaceholderFeatureScreen')));
    });
    test('complete local pilot scenario preserves accounting boundaries',
        () async {
      final source = _fixture();
      final supplier = await source.suppliers.createSupplier(
        const SupplierDraft(name: 'Ù…ÙˆØ±Ø¯ Ø§Ù„Ù‚Ù…Ø­', phone: '01011112222'),
      );
      final product = await source.products.createProduct(
        const ProductDraft(
          name: 'Ù‚Ù…Ø­ Ø¯Ø±Ø¬Ø© Ø£ÙˆÙ„Ù‰',
          unit: GrainUnit.kilogram,
          defaultSalePricePiastersPerKg: 1000,
          minimumSalePricePiastersPerKg: 900,
          referenceCostPricePiastersPerKg: 700,
        ),
      );

      await source.purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 1000,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 700,
          createdByUserId: _owner.id,
          notes: 'Ø¯ÙØ¹Ø© Ø£ÙˆÙ„Ù‰',
        ),
      );
      expect(await source.inventory.currentStockKg(product.id), 1000);

      final cashCustomer = await source.customers.createCustomer(
        const CustomerDraft(name: 'عميل نقدي', phone: '01033334445'),
      );
      final salesController = SaleController(
        saleRepository: source.sales,
        productRepository: source.products,
        inventoryRepository: source.inventory,
        customerRepository: source.customers,
      );
      await salesController.load(_owner);
      expect(salesController.stockForProduct(product.id), 1000);

      final saleCreated = await salesController.createSale(
        user: _owner,
        productId: product.id,
        quantityKg: 250,
        salePriceQirshPerKg: 1000,
        notes: 'Ø¨ÙŠØ¹ Ù†Ù‚Ø¯ÙŠ',
        customerId: cashCustomer.id,
      );
      expect(saleCreated, isTrue);
      expect(await source.inventory.currentStockKg(product.id), 750);

      final stockBeforeInvalidSale = await source.inventory.currentStockKg(
        product.id,
      );
      final invalidSale = await salesController.createSale(
        user: _owner,
        productId: product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 850,
        customerId: cashCustomer.id,
      );
      expect(invalidSale, isFalse);
      expect(
          salesController.errorMessage,
          contains(
              '\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649'));
      expect(await source.inventory.currentStockKg(product.id),
          stockBeforeInvalidSale);
      expect(await source.sales.listSales(), hasLength(1));

      final customer = await source.customers.createCustomer(
        const CustomerDraft(
          name: 'Ø¹Ù…ÙŠÙ„ ØªØ¬Ø±ÙŠØ¨ÙŠ ÙˆØ§Ø¶Ø­',
          phone: '01033334444',
          notes:
              'Ù„Ø§ ÙŠØªÙ… Ø¹Ø±Ø¶ Ø±ØµÙŠØ¯ Ù„Ù„Ø¹Ù…ÙŠÙ„ ÙÙŠ Ù‡Ø°Ù‡ Ø§Ù„Ù…Ø±Ø­Ù„Ø©',
        ),
      );
      expect(customer.isActive, isTrue);

      await source.expenses.createExpense(
        ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: _pilotDay,
          category: 'Ù†Ù‚Ù„',
          amountQirsh: 12500,
          createdByUserId: _owner.id,
          operationRequestId: 'phase32-expense-pilot',
          notes: 'Ù†Ù‚Ù„ Ù…Ù† Ø§Ù„Ù…ÙˆØ±Ø¯',
        ),
      );
      expect(await source.inventory.currentStockKg(product.id),
          stockBeforeInvalidSale);

      final report = await source.reports.dailyActivityReport(
        selectedDate: _pilotDay,
      );
      expect(report.totalPurchasedKg, 1000);
      expect(report.totalSoldKg, 250);
      expect(report.totalPurchaseAmountQirsh, 700000);
      expect(report.totalSalesAmountQirsh, 250000);
      expect(report.totalExpenseAmountQirsh, 12500);
      expect(report.estimatedGrossProfitQirsh, 75000);
      expect(report.hasCompleteSalesCost, isTrue);

      final history = await source.history.listHistory();
      expect(history, hasLength(2));
      expect(history.map((entry) => entry.productName), contains(product.name));

      final auditLogs = await source.audit.exportStoredAuditLogs();
      expect(
          auditLogs.map((log) => log.actionType), contains('customer.created'));
      expect(
          auditLogs.map((log) => log.actionType), contains('expense.created'));

      final backup = await source.exportService.createBackup();
      expect(backup.counts.products, 1);
      expect(backup.counts.inventoryMovements, 2);
      expect(backup.counts.suppliers, 1);
      expect(backup.counts.purchases, 1);
      expect(backup.counts.sales, 1);
      expect(backup.counts.documentHistory, 2);
      expect(backup.counts.customers, 2);
      expect(backup.counts.expenses, 1);
      expect(backup.counts.auditLogs, 3);

      final target = _fixture();
      final restore = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );
      expect(restore.success, isTrue);
      expect(await target.products.listProducts(), hasLength(1));
      expect(await target.inventory.listAllMovements(), hasLength(2));
      expect(await target.suppliers.listSuppliers(), hasLength(1));
      expect(await target.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await target.sales.listSales(), hasLength(1));
      expect(await target.history.listHistory(), hasLength(2));
      expect(await target.customers.listCustomers(), hasLength(2));
      expect(await target.expenses.listExpenses(), hasLength(1));
      expect(await target.audit.exportStoredAuditLogs(), hasLength(3));
    });

    test('reports do not invent profit when reference cost is missing',
        () async {
      final fixture = _fixture();
      final supplier = await fixture.suppliers.createSupplier(
        const SupplierDraft(name: 'Ù…ÙˆØ±Ø¯ Ø°Ø±Ø©'),
      );
      final product = await fixture.products.createProduct(
        const ProductDraft(
          name: 'Ø°Ø±Ø© Ø¨Ø¯ÙˆÙ† ØªÙƒÙ„ÙØ© Ù…Ø±Ø¬Ø¹ÙŠØ©',
          unit: GrainUnit.kilogram,
          defaultSalePricePiastersPerKg: 900,
        ),
      );
      await fixture.purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 600,
          createdByUserId: _owner.id,
        ),
      );
      final profitCustomer = await fixture.customers.createCustomer(
        const CustomerDraft(name: 'عميل تقرير', isActive: true),
      );
      await fixture.sales.createSale(
        SaleDraft(
          productId: product.id,
          quantityKg: 20,
          salePriceQirshPerKg: 900,
          createdByUserId: _owner.id,
          customerId: profitCustomer.id,
        ),
      );

      final report = await fixture.reports.dailyActivityReport(
        selectedDate: _pilotDay,
      );
      expect(report.totalSalesAmountQirsh, 18000);
      expect(report.estimatedGrossProfitQirsh, isNull);
      expect(report.hasCompleteSalesCost, isFalse);
      expect(report.missingSalesCostProductNames, contains(product.name));
    });

    test('old backups without Phase 31 lists remain previewable/restorable',
        () async {
      final source = _fixture();
      final product = await source.products.createProduct(
        const ProductDraft(name: 'Ù‚Ù…Ø­ Ù‚Ø¯ÙŠÙ…', unit: GrainUnit.kilogram),
      );
      await source.inventory.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 50,
          createdByUserId: _owner.id,
        ),
      );

      final backup =
          jsonDecode((await source.exportService.createBackup()).jsonText)
              as Map<String, Object?>;
      final counts = backup['counts'] as Map<String, Object?>;
      final data = backup['data'] as Map<String, Object?>;
      counts.remove('customers');
      counts.remove('expenses');
      counts.remove('auditLogs');
      data.remove('customers');
      data.remove('expenses');
      data.remove('auditLogs');
      final oldBackupText = const JsonEncoder.withIndent('  ').convert(backup);

      final preview =
          const BackupRestorePreviewService().preview(oldBackupText);
      expect(preview.isValid, isTrue);
      expect(preview.summary!.counts.customers, 0);
      expect(preview.summary!.counts.expenses, 0);
      expect(preview.summary!.counts.auditLogs, 0);
      expect(preview.warnings.join(' '),
          isNot(contains('\u063a\u064a\u0631 \u0645\u062a\u0627\u062d')));

      final target = _fixture();
      final restore = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: oldBackupText,
      );
      expect(restore.success, isTrue);
      expect(await target.products.listProducts(), hasLength(1));
      expect(await target.customers.listCustomers(), isEmpty);
      expect(await target.expenses.listExpenses(), isEmpty);
      expect(await target.audit.exportStoredAuditLogs(), isEmpty);
    });
  });
}

_Phase32Fixture _fixture() {
  final audit = LocalAuditLogRepository();
  final customers = LocalCustomerRepository(auditLogRepository: audit);
  final expenses = LocalExpenseRepository(auditLogRepository: audit);
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
  final reports = LocalReportRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    inventoryRepository: inventory,
    productRepository: products,
    expenseRepository: expenses,
  );
  final exportService = BackupExportService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    customerRepository: customers,
    expenseRepository: expenses,
    auditLogRepository: audit,
    now: () => DateTime.utc(2026, 7, 7, 10),
  );
  final restoreService = BackupRestoreService(
    productRepository: products,
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    customerRepository: customers,
    expenseRepository: expenses,
    auditLogRepository: audit,
  );

  return _Phase32Fixture(
    audit: audit,
    customers: customers,
    expenses: expenses,
    products: products,
    suppliers: suppliers,
    inventory: inventory,
    purchases: purchases,
    sales: sales,
    history: history,
    reports: reports,
    exportService: exportService,
    restoreService: restoreService,
  );
}

class _Phase32Fixture {
  const _Phase32Fixture({
    required this.audit,
    required this.customers,
    required this.expenses,
    required this.products,
    required this.suppliers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.reports,
    required this.exportService,
    required this.restoreService,
  });

  final LocalAuditLogRepository audit;
  final LocalCustomerRepository customers;
  final LocalExpenseRepository expenses;
  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final LocalReportRepository reports;
  final BackupExportService exportService;
  final BackupRestoreService restoreService;
}

final _pilotDay = DateTime.now();
final _now = DateTime(2026, 1, 1);

final _owner = AppUser(
  id: 'owner-test',
  name: 'Ù…Ø§Ù„Ùƒ',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);
