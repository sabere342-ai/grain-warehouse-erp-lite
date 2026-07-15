import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class AppRepositories {
  AppRepositories._();

  static final LocalAuditLogRepository auditLogRepository =
      LocalAuditLogRepository();

  /// The application owns exactly one authentication store. Approval checks
  /// and the visible session must observe the same active/inactive users.
  static final LocalAuthRepository authRepository = LocalAuthRepository.empty();

  static final LocalNegativeBalanceApprovalRepository
      negativeBalanceApprovalRepository = LocalNegativeBalanceApprovalRepository();

  static final NegativeBalanceApprovalService negativeBalanceApprovalService =
      NegativeBalanceApprovalService(
    authRepository: authRepository,
    approvalRepository: negativeBalanceApprovalRepository,
    auditLogRepository: auditLogRepository,
  );

  static final LocalBusinessIdentityRepository businessIdentityRepository =
      LocalBusinessIdentityRepository(auditLogRepository: auditLogRepository);

  static final LocalFinancialAccountRepository financialAccountRepository =
      LocalFinancialAccountRepository(
    auditLogRepository: auditLogRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );

  static final LocalCustomerRepository customerRepository =
      LocalCustomerRepository(auditLogRepository: auditLogRepository);

  static final LocalCustomerAccountRepository customerAccountRepository =
      LocalCustomerAccountRepository(
    customerRepository: customerRepository,
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );

  static final LocalExpenseRepository expenseRepository =
      LocalExpenseRepository(
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
  );

  static late final FoundationDatabase database;
  static ProductDataRepository _productRepository = LocalProductRepository();
  static ProductDataRepository get productRepository => _productRepository;

  static Future<void> initializeProduction() async {
    database = await openProductionDatabase();
    _productRepository = DriftProductRepository(database);
  }

  static Future<void> close() => database.close();

  static final LocalInventoryRepository inventoryRepository =
      LocalInventoryRepository(productRepository: productRepository);

  static final LocalSupplierRepository supplierRepository =
      LocalSupplierRepository();

  static final LocalSupplierAccountRepository supplierAccountRepository =
      LocalSupplierAccountRepository(
    supplierRepository: supplierRepository,
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );

  static final LocalPurchaseRepository purchaseRepository =
      LocalPurchaseRepository(
    supplierRepository: supplierRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
    supplierAccountRepository: supplierAccountRepository,
    financialAccountRepository: financialAccountRepository,
  );

  static final LocalSaleRepository saleRepository = LocalSaleRepository(
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static final LocalReportRepository reportRepository = LocalReportRepository(
    purchaseRepository: purchaseRepository,
    saleRepository: saleRepository,
    inventoryRepository: inventoryRepository,
    productRepository: productRepository,
    expenseRepository: expenseRepository,
    customerAccountRepository: customerAccountRepository,
    supplierAccountRepository: supplierAccountRepository,
  );

  static final LocalDocumentHistoryRepository documentHistoryRepository =
      LocalDocumentHistoryRepository(
    purchaseRepository: purchaseRepository,
    saleRepository: saleRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
  );

  static BackupExportService get backupExportService => BackupExportService(
        businessIdentityRepository: businessIdentityRepository,
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
        financialAccountRepository: financialAccountRepository,
      );

  static BackupRestoreService get backupRestoreService => BackupRestoreService(
        businessIdentityRepository: businessIdentityRepository,
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
        financialAccountRepository: financialAccountRepository,
      );

  static BusinessDataWipeService get businessDataWipeService =>
      BusinessDataWipeService(
        backupExportService: backupExportService,
        backupFileWriter: const LocalBackupFileWriter(),
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
        financialAccountRepository: financialAccountRepository,
      );
}
