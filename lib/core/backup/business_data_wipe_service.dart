import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class BusinessDataWipeService {
  BusinessDataWipeService({
    required BackupExportService backupExportService,
    required BackupFileWriter backupFileWriter,
    required LocalProductRepository productRepository,
    required LocalInventoryRepository inventoryRepository,
    required LocalSupplierRepository supplierRepository,
    required LocalPurchaseRepository purchaseRepository,
    required LocalSaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    LocalCustomerRepository? customerRepository,
    LocalCustomerAccountRepository? customerAccountRepository,
    LocalSupplierAccountRepository? supplierAccountRepository,
    LocalExpenseRepository? expenseRepository,
    LocalAuditLogRepository? auditLogRepository,
    LocalFinancialAccountRepository? financialAccountRepository,
    BackupRestorePreviewService previewService =
        const BackupRestorePreviewService(),
  })  : _backupExportService = backupExportService,
        _backupFileWriter = backupFileWriter,
        _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _customerRepository = customerRepository ?? LocalCustomerRepository(),
        _customerAccountRepository = customerAccountRepository ?? LocalCustomerAccountRepository(customerRepository: customerRepository ?? LocalCustomerRepository()),
        _supplierAccountRepository = supplierAccountRepository ?? LocalSupplierAccountRepository(supplierRepository: supplierRepository),
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository ?? LocalFinancialAccountRepository(),
        _previewService = previewService;

  static const confirmationPhrase =
      '\u0627\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644';

  final BackupExportService _backupExportService;
  final BackupFileWriter _backupFileWriter;
  final LocalProductRepository _productRepository;
  final LocalInventoryRepository _inventoryRepository;
  final LocalSupplierRepository _supplierRepository;
  final LocalPurchaseRepository _purchaseRepository;
  final LocalSaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
  final LocalCustomerRepository _customerRepository;
  final LocalCustomerAccountRepository _customerAccountRepository;
  final LocalSupplierAccountRepository _supplierAccountRepository;
  final LocalExpenseRepository _expenseRepository;
  final LocalAuditLogRepository _auditLogRepository;
  final LocalFinancialAccountRepository _financialAccountRepository;
  final BackupRestorePreviewService _previewService;

  Future<BusinessDataWipeResult> wipeBusinessData({
    required AppUser? user,
    required String confirmationText,
  }) async {
    if (user?.permissions.canWipeBusinessData != true) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u0647\u0630\u0647 \u0627\u0644\u0623\u062f\u0627\u0629 \u0645\u062a\u0627\u062d\u0629 \u0644\u0644\u0645\u0627\u0644\u0643 \u0641\u0642\u0637.',
        technicalReason: 'not-owner',
      );
    }
    if (confirmationText != confirmationPhrase) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u0627\u0643\u062a\u0628 \u0639\u0628\u0627\u0631\u0629 \u0627\u0644\u062a\u0623\u0643\u064a\u062f \u0643\u0645\u0627 \u0647\u064a \u0644\u0644\u0645\u062a\u0627\u0628\u0639\u0629.',
        technicalReason: 'invalid-confirmation',
      );
    }

    try {
      final backup = await _backupExportService.createBackup();
      BackupExportValidator.validateJsonText(backup.jsonText);
      if (!BackupFileName.isSafeWindowsFileName(backup.fileName)) {
        throw const BackupExportValidationException();
      }
      final preview = _previewService.preview(backup.jsonText);
      if (!preview.isValid) {
        throw const BackupExportValidationException();
      }

      final saveResult = await _backupFileWriter.save(
        fileName: backup.fileName,
        jsonText: backup.jsonText,
      );
      final counts = await _currentCounts();

      // This is a destructive operational reset after a completed backup.
      // It intentionally does not create cancellation documents or reversals.
      await _auditLogRepository.clearForOwnerDataWipe();
      await _expenseRepository.clearForOwnerDataWipe();
      await _customerRepository.clearForOwnerDataWipe();
      await _customerAccountRepository.clearForOwnerDataWipe();
      await _saleRepository.clearForOwnerDataWipe();
      await _purchaseRepository.clearForOwnerDataWipe();
      await _supplierAccountRepository.clearForOwnerDataWipe();
      await _inventoryRepository.clearForOwnerDataWipe();
      await _supplierRepository.clearForOwnerDataWipe();
      await _productRepository.clearForOwnerDataWipe();
      await _financialAccountRepository.clearForOwnerDataWipe();

      return BusinessDataWipeResult.success(
        backupSaveResult: saveResult,
        wipedCounts: counts,
        warnings: const [
          '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644 \u0648\u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0644\u0645 \u064a\u062a\u0645 \u062d\u0630\u0641\u0647\u0627.',
          '\u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0627\u0644\u0628\u062f\u0621 \u0645\u0646 \u062c\u062f\u064a\u062f \u0623\u0648 \u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0635\u0627\u0644\u062d\u0629 \u0625\u0644\u0649 \u0646\u0638\u0627\u0645 \u0641\u0627\u0631\u063a.',
        ],
      );
    } catch (_) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u062a\u0645 \u0625\u064a\u0642\u0627\u0641 \u0627\u0644\u0645\u0633\u062d \u0644\u0623\u0646 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0644\u0645 \u062a\u0643\u062a\u0645\u0644 \u0628\u0646\u062c\u0627\u062d. \u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u0623\u064a \u0628\u064a\u0627\u0646\u0627\u062a.',
        technicalReason: 'backup-required-failed',
      );
    }
  }

  Future<BusinessDataWipeCounts> _currentCounts() async {
    final products = await _productRepository.listProducts(
      includeInactive: true,
    );
    final movements = await _inventoryRepository.listAllMovements();
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    final purchases = await _purchaseRepository.listPurchaseIntakes();
    final sales = await _saleRepository.listSales();
    final history = await _documentHistoryRepository.listHistory();
    final customers = await _customerRepository.listCustomers(includeInactive: true);
    final expenses = await _expenseRepository.listExpenses();
    final auditLogs = await _auditLogRepository.listLogs();

    return BusinessDataWipeCounts(
      products: products.length,
      inventoryMovements: movements.length,
      suppliers: suppliers.length,
      purchases: purchases.length,
      sales: sales.length,
      documentHistory: history.length,
      customers: customers.length,
      expenses: expenses.length,
      auditLogs: auditLogs.length,
    );
  }
}

class BusinessDataWipeResult {
  const BusinessDataWipeResult._({
    required this.success,
    required this.message,
    required this.warnings,
    this.backupSaveResult,
    this.wipedCounts,
    this.technicalReason,
  });

  factory BusinessDataWipeResult.success({
    required BackupFileSaveResult backupSaveResult,
    required BusinessDataWipeCounts wipedCounts,
    required List<String> warnings,
  }) {
    return BusinessDataWipeResult._(
      success: true,
      message:
          '\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u062b\u0645 \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0628\u0646\u062c\u0627\u062d.',
      backupSaveResult: backupSaveResult,
      wipedCounts: wipedCounts,
      warnings: warnings,
    );
  }

  const factory BusinessDataWipeResult.failure({
    required String message,
    required String technicalReason,
  }) = BusinessDataWipeFailureResult;

  final bool success;
  final String message;
  final BackupFileSaveResult? backupSaveResult;
  final BusinessDataWipeCounts? wipedCounts;
  final List<String> warnings;
  final String? technicalReason;
}

class BusinessDataWipeFailureResult extends BusinessDataWipeResult {
  const BusinessDataWipeFailureResult({
    required super.message,
    required super.technicalReason,
  }) : super._(
          success: false,
          warnings: const [],
        );
}

class BusinessDataWipeCounts {
  const BusinessDataWipeCounts({
    required this.products,
    required this.inventoryMovements,
    required this.suppliers,
    required this.purchases,
    required this.sales,
    required this.documentHistory,
    required this.customers,
    required this.expenses,
    required this.auditLogs,
  });

  final int products;
  final int inventoryMovements;
  final int suppliers;
  final int purchases;
  final int sales;
  final int documentHistory;
  final int customers;
  final int expenses;
  final int auditLogs;
}
