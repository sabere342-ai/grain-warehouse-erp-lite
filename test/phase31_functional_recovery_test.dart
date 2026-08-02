import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_controller.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_controller.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 31 customers', () {
    test('add edit disable and reactivate customers records audit logs',
        () async {
      final audit = LocalAuditLogRepository();
      final repository = LocalCustomerRepository(auditLogRepository: audit);
      final controller = CustomerController(repository: repository);

      final created = await controller.createCustomer(
        user: _owner,
        draft: const CustomerDraft(
          name: 'عميل القمح',
          phone: '01022223333',
          notes: 'استلام من المخزن',
        ),
      );
      expect(created, isTrue);
      expect(controller.customers.single.name, 'عميل القمح');

      final customerId = controller.customers.single.id;
      final edited = await controller.updateCustomer(
        user: _owner,
        customerId: customerId,
        draft: const CustomerDraft(
          name: 'عميل القمح المعدل',
          phone: '01022223333',
          notes: 'ملاحظة محدثة',
        ),
      );
      expect(edited, isTrue);
      expect(controller.customers.single.name, 'عميل القمح المعدل');

      expect(
        await controller.setCustomerActive(
          user: _owner,
          customerId: customerId,
          isActive: false,
        ),
        isTrue,
      );
      expect(controller.customers.single.isActive, isFalse);

      expect(
        await controller.setCustomerActive(
          user: _owner,
          customerId: customerId,
          isActive: true,
        ),
        isTrue,
      );
      expect(controller.customers.single.isActive, isTrue);

      final logs = await audit.exportStoredAuditLogs();
      expect(logs.map((log) => log.actionType), contains('customer.created'));
      expect(logs.map((log) => log.actionType), contains('customer.updated'));
      expect(logs.map((log) => log.actionType), contains('customer.disabled'));
      expect(
          logs.map((log) => log.actionType), contains('customer.reactivated'));
    });
  });

  group('Phase 31 expenses', () {
    test('validates amount and category and persists successful expense',
        () async {
      final repository = LocalExpenseRepository();
      final controller = ExpenseController(repository: repository);

      expect(
        await controller.createExpense(
          user: _owner,
          draft: ExpenseDraft(
            accountingClassification: ExpenseAccountingClassification.operating,
            date: _day,
            category: '',
            amountQirsh: 1000,
            createdByUserId: _owner.id,
            operationRequestId: 'phase31-expense-invalid-category',
          ),
        ),
        isFalse,
      );
      expect(
        await controller.createExpense(
          user: _owner,
          draft: ExpenseDraft(
            accountingClassification: ExpenseAccountingClassification.operating,
            date: _day,
            category: 'نقل',
            amountQirsh: 0,
            createdByUserId: _owner.id,
            operationRequestId: 'phase31-expense-invalid-amount',
          ),
        ),
        isFalse,
      );

      expect(
        await controller.createExpense(
          user: _owner,
          draft: ExpenseDraft(
            accountingClassification: ExpenseAccountingClassification.operating,
            date: _day,
            category: 'نقل',
            amountQirsh: 12550,
            createdByUserId: _owner.id,
            operationRequestId: 'phase31-expense-valid',
            notes: 'نقل جوالات',
          ),
        ),
        isTrue,
      );
      expect(controller.expenses.single.category, 'نقل');
      expect(controller.expenses.single.amountQirsh, 12550);
    });

    test('expenses do not mutate inventory and appear in daily reports',
        () async {
      final fixture = _fixture();
      final product = await fixture.products.createProduct(
        const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
      );
      await fixture.inventory.createMovement(
        StockMovementDraft(
          productId: product.id,
          movementType: StockMovementType.openingBalance,
          quantityKg: 1000,
          createdByUserId: _owner.id,
        ),
      );
      final before = await fixture.inventory.currentStockKg(product.id);

      await fixture.expenses.createExpense(
        ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: _day,
          category: 'كهرباء',
          amountQirsh: 30000,
          createdByUserId: _owner.id,
          operationRequestId: 'phase31-expense-report',
        ),
      );

      expect(await fixture.inventory.currentStockKg(product.id), before);
      final report = await fixture.reports.dailyActivityReport(
        selectedDate: _day,
      );
      expect(report.totalExpenseAmountQirsh, 30000);
    });
  });

  group('Phase 31 audit logs', () {
    test('audit logs are recorded and owner-only controller is read-only',
        () async {
      final audit = LocalAuditLogRepository();
      await audit.record(
        AuditLogDraft(
          actionType: 'manual.test',
          descriptionAr: 'حدث اختبار',
          referenceId: 'ref-1',
          timestamp: _day,
        ),
      );
      final controller = AuditLogController(repository: audit);

      expect(await controller.loadLogs(_employee), isFalse);
      expect(controller.entries, isEmpty);
      expect(await controller.loadLogs(_owner), isTrue);
      expect(controller.entries.single.descriptionAr, 'حدث اختبار');
      expect(controller.entries.single.referenceId, 'ref-1');
    });
  });

  group('Phase 31 backup and restore', () {
    test('backup and restore preserve customers expenses and audit logs',
        () async {
      final source = _fixture();
      await source.customers.createCustomer(
        const CustomerDraft(name: 'عميل النسخة', phone: '01099990000'),
      );
      await source.expenses.createExpense(
        ExpenseDraft(
          accountingClassification: ExpenseAccountingClassification.operating,
          date: _day,
          category: 'نولون',
          amountQirsh: 45000,
          createdByUserId: _owner.id,
          operationRequestId: 'phase31-expense-backup',
        ),
      );
      await source.audit.record(
        AuditLogDraft(
          actionType: 'manual.audit',
          descriptionAr: 'سجل محفوظ',
          referenceId: 'audit-ref',
          timestamp: _day,
        ),
      );

      final backup = await source.exportService.createBackup();
      expect(backup.counts.customers, 1);
      expect(backup.counts.expenses, 1);
      expect(backup.counts.auditLogs, greaterThanOrEqualTo(3));

      final target = _fixture();
      final result = await target.restoreService.restoreToEmpty(
        user: _owner,
        jsonText: backup.jsonText,
      );

      expect(result.success, isTrue);
      expect(await target.customers.listCustomers(), hasLength(1));
      expect(await target.expenses.listExpenses(), hasLength(1));
      final restoredLogs = await target.audit.exportStoredAuditLogs();
      expect(
          restoredLogs.map((log) => log.actionType), contains('manual.audit'));
    });
  });
}

_Phase31Fixture _fixture() {
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
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
  );
  final reports = LocalReportRepository(
    purchaseRepository: purchases,
    saleRepository: sales,
    inventoryRepository: inventory,
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    expenseRepository: expenses,
  );
  final exportService = BackupExportService(
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
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
    productCatalogReadRepository:
        ProductCatalogReadRepositoryTestAdapter(products),
    inventoryRepository: inventory,
    supplierRepository: suppliers,
    purchaseRepository: purchases,
    saleRepository: sales,
    documentHistoryRepository: history,
    customerRepository: customers,
    expenseRepository: expenses,
    auditLogRepository: audit,
  );

  return _Phase31Fixture(
    audit: audit,
    customers: customers,
    expenses: expenses,
    products: products,
    inventory: inventory,
    reports: reports,
    exportService: exportService,
    restoreService: restoreService,
  );
}

class _Phase31Fixture {
  const _Phase31Fixture({
    required this.audit,
    required this.customers,
    required this.expenses,
    required this.products,
    required this.inventory,
    required this.reports,
    required this.exportService,
    required this.restoreService,
  });

  final LocalAuditLogRepository audit;
  final LocalCustomerRepository customers;
  final LocalExpenseRepository expenses;
  final LocalProductRepository products;
  final LocalInventoryRepository inventory;
  final LocalReportRepository reports;
  final BackupExportService exportService;
  final BackupRestoreService restoreService;
}

final _day = DateTime(2026, 7, 7, 12);
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
