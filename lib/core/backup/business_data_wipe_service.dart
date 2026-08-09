import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

typedef BusinessDataWipeTransactionRunner = Future<void> Function(
  Future<void> Function() operation,
);

typedef BusinessDataWipeStepHook = void Function(BusinessDataWipeStep step);

enum BusinessDataWipeStep {
  negativeBalanceApprovalRequests,
  auditLogs,
  expenses,
  customers,
  customerAccounts,
  sales,
  purchases,
  supplierAccounts,
  inventoryValuation,
  inventory,
  suppliers,
  products,
  financialAccounts,
}

class BusinessDataWipeService {
  BusinessDataWipeService({
    required BackupExportService backupExportService,
    required BackupFileWriter backupFileWriter,
    required ProductDataRepository productRepository,
    required ProductCatalogReadRepository productCatalogReadRepository,
    required DurableInventoryRepository inventoryRepository,
    required SupplierDataRepository supplierRepository,
    required DurablePurchaseRepository purchaseRepository,
    required DurableSaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    required BusinessDataWipeTransactionRunner transactionRunner,
    CustomerDataRepository? customerRepository,
    DurableCustomerAccountRepository? customerAccountRepository,
    DurableSupplierAccountRepository? supplierAccountRepository,
    DurableExpenseRepository? expenseRepository,
    DurableAuditLogRepository? auditLogRepository,
    LocalFinancialAccountRepository? financialAccountRepository,
    DurableNegativeBalanceApprovalRequestRepository?
        negativeBalanceApprovalRequestRepository,
    DurableInventoryValuationRepository? inventoryValuationRepository,
    BackupRestorePreviewService previewService =
        const BackupRestorePreviewService(),
    BusinessDataWipeStepHook? stepHook,
  })  : _backupExportService = backupExportService,
        _backupFileWriter = backupFileWriter,
        _productRepository = productRepository,
        _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _transactionRunner = transactionRunner,
        _customerRepository = customerRepository ?? LocalCustomerRepository(),
        _customerAccountRepository = customerAccountRepository ??
            LocalCustomerAccountRepository(
                customerRepository:
                    customerRepository ?? LocalCustomerRepository()),
        _supplierAccountRepository = supplierAccountRepository ??
            LocalSupplierAccountRepository(
                supplierRepository: supplierRepository),
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository =
            financialAccountRepository ?? LocalFinancialAccountRepository(),
        _negativeBalanceApprovalRequestRepository =
            negativeBalanceApprovalRequestRepository ??
                LocalNegativeBalanceApprovalRequestRepository(),
        _inventoryValuationRepository =
            inventoryValuationRepository ?? LocalInventoryValuationRepository(),
        _previewService = previewService,
        _stepHook = stepHook;

  static const confirmationPhrase =
      '\u0627\u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644';

  final BackupExportService _backupExportService;
  final BackupFileWriter _backupFileWriter;
  final ProductDataRepository _productRepository;
  final ProductCatalogReadRepository _productCatalogReadRepository;
  final DurableInventoryRepository _inventoryRepository;
  final SupplierDataRepository _supplierRepository;
  final DurablePurchaseRepository _purchaseRepository;
  final DurableSaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
  final BusinessDataWipeTransactionRunner _transactionRunner;
  final CustomerDataRepository _customerRepository;
  final DurableCustomerAccountRepository _customerAccountRepository;
  final DurableSupplierAccountRepository _supplierAccountRepository;
  final DurableExpenseRepository _expenseRepository;
  final DurableAuditLogRepository _auditLogRepository;
  final LocalFinancialAccountRepository _financialAccountRepository;
  final DurableNegativeBalanceApprovalRequestRepository
      _negativeBalanceApprovalRequestRepository;
  final DurableInventoryValuationRepository _inventoryValuationRepository;
  final BackupRestorePreviewService _previewService;
  final BusinessDataWipeStepHook? _stepHook;

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

    late final BackupFileSaveResult saveResult;
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

      saveResult = await _backupFileWriter.save(
        fileName: backup.fileName,
        jsonText: backup.jsonText,
      );
    } catch (_) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u062a\u0645 \u0625\u064a\u0642\u0627\u0641 \u0627\u0644\u0645\u0633\u062d \u0644\u0623\u0646 \u0627\u0644\u0646\u0633\u062e\u0629 \u0627\u0644\u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0644\u0645 \u062a\u0643\u062a\u0645\u0644 \u0628\u0646\u062c\u0627\u062d. \u0644\u0646 \u064a\u062a\u0645 \u062d\u0630\u0641 \u0623\u064a \u0628\u064a\u0627\u0646\u0627\u062a.',
        technicalReason: 'backup-required-failed',
      );
    }

    late final BusinessDataWipeCounts counts;
    try {
      counts = await _currentCounts();
    } catch (_) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u062a\u0639\u0630\u0631 \u0628\u062f\u0621 \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644. \u0644\u0645 \u064a\u062a\u0645 \u062d\u0630\u0641 \u0623\u064a \u0628\u064a\u0627\u0646\u0627\u062a.',
        technicalReason: 'wipe-preparation-failed',
      );
    }

    try {
      await _transactionRunner(
        () => RepositoryTransaction.execute(_transactionSnapshots(), () async {
          // This is a destructive operational reset after a completed backup.
          // It intentionally does not create cancellation documents or
          // reversals. Every step is governed by the caller-provided durable
          // transaction and the repository snapshots in this boundary.
          await _runStep(
            BusinessDataWipeStep.negativeBalanceApprovalRequests,
            () => _negativeBalanceApprovalRequestRepository
                .clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.auditLogs,
            () => _auditLogRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.expenses,
            () => _expenseRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.customers,
            () => _customerRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.customerAccounts,
            () => _customerAccountRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.sales,
            () => _saleRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.purchases,
            () => _purchaseRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.supplierAccounts,
            () => _supplierAccountRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.inventoryValuation,
            () => _inventoryValuationRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.inventory,
            () => _inventoryRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.suppliers,
            () => _supplierRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.products,
            () => _productRepository.clearForOwnerDataWipe(),
          );
          await _runStep(
            BusinessDataWipeStep.financialAccounts,
            () => _financialAccountRepository.clearForOwnerDataWipe(),
          );
        }),
      );
    } catch (_) {
      return const BusinessDataWipeResult.failure(
        message:
            '\u062a\u0639\u0630\u0631 \u0645\u0633\u062d \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0634\u063a\u064a\u0644 \u0648\u062a\u0645 \u0627\u0644\u062a\u0631\u0627\u062c\u0639 \u0639\u0646 \u0627\u0644\u0639\u0645\u0644\u064a\u0629. \u0644\u0645 \u064a\u062a\u0645 \u0627\u0639\u062a\u0645\u0627\u062f \u062d\u0630\u0641 \u062c\u0632\u0626\u064a.',
        technicalReason: 'business-data-wipe-rolled-back',
      );
    }

    return BusinessDataWipeResult.success(
      backupSaveResult: saveResult,
      wipedCounts: counts,
      warnings: const [
        '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644 \u0648\u062d\u0633\u0627\u0628 \u0627\u0644\u0645\u0627\u0644\u0643 \u0644\u0645 \u064a\u062a\u0645 \u062d\u0630\u0641\u0647\u0627.',
        '\u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0622\u0646 \u0627\u0644\u0628\u062f\u0621 \u0645\u0646 \u062c\u062f\u064a\u062f \u0623\u0648 \u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0646\u0633\u062e\u0629 \u0627\u062d\u062a\u064a\u0627\u0637\u064a\u0629 \u0635\u0627\u0644\u062d\u0629 \u0625\u0644\u0649 \u0646\u0638\u0627\u0645 \u0641\u0627\u0631\u063a.',
      ],
    );
  }

  List<SnapshotHolder> _transactionSnapshots() => [
        _negativeBalanceApprovalRequestRepository.createTransactionSnapshot(),
        _auditLogRepository.createTransactionSnapshot(),
        _expenseRepository.createTransactionSnapshot(),
        _customerRepository.createTransactionSnapshot(),
        _customerAccountRepository.createTransactionSnapshot(),
        _saleRepository.createTransactionSnapshot(),
        _purchaseRepository.createTransactionSnapshot(),
        _supplierAccountRepository.createTransactionSnapshot(),
        _inventoryValuationRepository.createTransactionSnapshot(),
        _inventoryRepository.createTransactionSnapshot(),
        _supplierRepository.createTransactionSnapshot(),
        _productRepository.createTransactionSnapshot(),
        _financialAccountRepository.createTransactionSnapshot(),
      ];

  Future<void> _runStep(
    BusinessDataWipeStep step,
    Future<void> Function() operation,
  ) async {
    _stepHook?.call(step);
    await operation();
  }

  Future<BusinessDataWipeCounts> _currentCounts() async {
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    final movements = await _inventoryRepository.listAllMovements();
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    final purchases = await _purchaseRepository.listPurchaseIntakes();
    final sales = await _saleRepository.listSales();
    final history = await _documentHistoryRepository.listHistory();
    final customers =
        await _customerRepository.listCustomers(includeInactive: true);
    final expenses = await _expenseRepository.listExpenses();
    final auditLogs = await _auditLogRepository.exportStoredAuditLogs();

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
