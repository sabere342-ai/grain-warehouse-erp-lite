import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/drift_auth_repository.dart';
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
import 'package:grain_warehouse_erp_lite/core/customer_accounts/drift_customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_workflow_service.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/profitability_activation_service.dart';
import 'package:grain_warehouse_erp_lite/core/profitability/profitability_report_service.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/drift_supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';

class AppRepositories {
  AppRepositories._();

  static DurableAuditLogRepository _auditLogRepository =
      LocalAuditLogRepository();
  static DurableAuditLogRepository get auditLogRepository =>
      _auditLogRepository;

  /// The application owns exactly one authentication store. Approval checks
  /// and the visible session must observe the same active/inactive users.
  static AuthRepository authRepository = LocalAuthRepository.empty();

  static final LocalNegativeBalanceApprovalRepository
      negativeBalanceApprovalRepository =
      LocalNegativeBalanceApprovalRepository();

  static NegativeBalanceApprovalService negativeBalanceApprovalService =
      NegativeBalanceApprovalService(
    authRepository: authRepository,
    approvalRepository: negativeBalanceApprovalRepository,
    auditLogRepository: auditLogRepository,
  );

  static DurableNegativeBalanceApprovalRequestRepository
      _negativeBalanceApprovalRequestRepository =
      LocalNegativeBalanceApprovalRequestRepository();
  static DurableNegativeBalanceApprovalRequestRepository
      get negativeBalanceApprovalRequestRepository =>
          _negativeBalanceApprovalRequestRepository;

  static LocalBusinessIdentityRepository businessIdentityRepository =
      LocalBusinessIdentityRepository(auditLogRepository: auditLogRepository);

  static LocalFinancialAccountRepository _financialAccountRepository =
      LocalFinancialAccountRepository(
    auditLogRepository: auditLogRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );
  static LocalFinancialAccountRepository get financialAccountRepository =>
      _financialAccountRepository;

  static CustomerDataRepository _customerRepository =
      LocalCustomerRepository(auditLogRepository: auditLogRepository);
  static CustomerDataRepository get customerRepository => _customerRepository;

  static SupplierDataRepository _supplierRepository = LocalSupplierRepository();
  static SupplierDataRepository get supplierRepository => _supplierRepository;

  static DurableCustomerAccountRepository customerAccountRepository =
      LocalCustomerAccountRepository(
    customerRepository: customerRepository,
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );

  static DurableExpenseRepository expenseRepository = LocalExpenseRepository(
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
  );

  static late final FoundationDatabase database;
  static ProductDataRepository _productRepository = LocalProductRepository();
  static ProductDataRepository get productRepository => _productRepository;

  static Future<void> initializeProduction({
    Future<FoundationDatabase> Function()? databaseFactory,
  }) async {
    database = await (databaseFactory?.call() ?? openProductionDatabase());
    authRepository = DriftAuthRepository(database);
    _auditLogRepository = DriftAuditLogRepository(database);
    negativeBalanceApprovalService = NegativeBalanceApprovalService(
      authRepository: authRepository,
      approvalRepository: negativeBalanceApprovalRepository,
      auditLogRepository: auditLogRepository,
    );
    _negativeBalanceApprovalRequestRepository =
        DriftNegativeBalanceApprovalRequestRepository(database);
    businessIdentityRepository =
        LocalBusinessIdentityRepository(auditLogRepository: auditLogRepository);
    _financialAccountRepository = await DriftFinancialAccountRepository.open(
      database,
      auditLogRepository: auditLogRepository,
      negativeBalanceApprovalService: negativeBalanceApprovalService,
    );
    _productRepository = DriftProductRepository(database);
    _customerRepository = DriftCustomerRepository(
      database,
      auditLogRepository: auditLogRepository,
    );
    _supplierRepository = DriftSupplierRepository(database);
    customerAccountRepository = DriftCustomerAccountRepository(
      database,
      customerRepository: customerRepository,
      auditLogRepository: auditLogRepository,
      financialAccountRepository: financialAccountRepository,
      negativeBalanceApprovalService: negativeBalanceApprovalService,
    );
    expenseRepository = DriftExpenseRepository(
      database,
      auditLogRepository: auditLogRepository,
      financialAccountRepository: financialAccountRepository,
    );
    supplierAccountRepository = DriftSupplierAccountRepository(
      database,
      supplierRepository: supplierRepository,
      auditLogRepository: auditLogRepository,
      financialAccountRepository: financialAccountRepository,
      negativeBalanceApprovalService: negativeBalanceApprovalService,
    );
    _inventoryRepository = DriftInventoryRepository(
      database,
      productRepository: productRepository,
    );
    _inventoryValuationRepository = DriftInventoryValuationRepository(database);
    _purchaseRepository = DriftPurchaseRepository(
      database,
      supplierRepository: supplierRepository,
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
      supplierAccountRepository: supplierAccountRepository,
      financialAccountRepository: financialAccountRepository,
      auditLogRepository: auditLogRepository,
      inventoryValuationRepository: inventoryValuationRepository,
    );
    _saleRepository = DriftSaleRepository(
      database,
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
      inventoryValuationRepository: inventoryValuationRepository,
      financialAccountRepository: financialAccountRepository,
    );
  }

  static Future<void> close() => database.close();

  static DurableInventoryRepository _inventoryRepository =
      LocalInventoryRepository(
    productRepository: productRepository,
  );
  static DurableInventoryRepository get inventoryRepository =>
      _inventoryRepository;

  static DurableInventoryValuationRepository _inventoryValuationRepository =
      LocalInventoryValuationRepository();
  static DurableInventoryValuationRepository get inventoryValuationRepository =>
      _inventoryValuationRepository;

  static ProfitabilityActivationService get profitabilityActivationService =>
      ProfitabilityActivationService(
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        valuationRepository: inventoryValuationRepository,
        auditLogRepository: auditLogRepository,
        ensureDateOpen: financialAccountRepository.ensureDateIsOpen,
      );

  static ProfitabilityReportService get profitabilityReportService =>
      ProfitabilityReportService(
        inventoryValuationRepository: inventoryValuationRepository,
        saleRepository: saleRepository,
        expenseRepository: expenseRepository,
      );

  static DurableSupplierAccountRepository supplierAccountRepository =
      LocalSupplierAccountRepository(
    supplierRepository: supplierRepository,
    auditLogRepository: auditLogRepository,
    financialAccountRepository: financialAccountRepository,
    negativeBalanceApprovalService: negativeBalanceApprovalService,
  );

  static DurablePurchaseRepository _purchaseRepository =
      LocalPurchaseRepository(
    supplierRepository: supplierRepository,
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
    supplierAccountRepository: supplierAccountRepository,
    financialAccountRepository: financialAccountRepository,
    inventoryValuationRepository: inventoryValuationRepository,
  );

  static DurableSaleRepository _saleRepository = LocalSaleRepository(
    productRepository: productRepository,
    inventoryRepository: inventoryRepository,
    inventoryValuationRepository: inventoryValuationRepository,
    financialAccountRepository: financialAccountRepository,
  );
  static DurableSaleRepository get saleRepository => _saleRepository;

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
        negativeBalanceApprovalRequestRepository:
            negativeBalanceApprovalRequestRepository,
        inventoryValuationRepository: inventoryValuationRepository,
      );
  static DurablePurchaseRepository get purchaseRepository =>
      _purchaseRepository;

  static NegativeBalanceApprovalWorkflowService
      get negativeBalanceApprovalWorkflowService =>
          NegativeBalanceApprovalWorkflowService(
            authRepository: authRepository,
            requestRepository: negativeBalanceApprovalRequestRepository,
            legacyApprovalService: negativeBalanceApprovalService,
            auditLogRepository: auditLogRepository,
            financialAccountRepository: financialAccountRepository,
            supplierRepository: supplierRepository,
            supplierAccountRepository: supplierAccountRepository,
            expenseRepository: expenseRepository,
            purchaseRepository: purchaseRepository,
            productRepository: productRepository,
            inventoryRepository: inventoryRepository,
            durableTransactionRunner: (operation) =>
                database.inTransaction(operation),
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
        negativeBalanceApprovalRequestRepository:
            negativeBalanceApprovalRequestRepository,
        inventoryValuationRepository: inventoryValuationRepository,
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
        negativeBalanceApprovalRequestRepository:
            negativeBalanceApprovalRequestRepository,
        inventoryValuationRepository: inventoryValuationRepository,
      );
}
