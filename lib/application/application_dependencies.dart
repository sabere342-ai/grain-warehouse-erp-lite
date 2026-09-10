import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_inbox_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_outbox_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_sync_checkpoint_repository.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_sync_transaction_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class ApplicationDependencies {
  const ApplicationDependencies({
    required this.repositories,
    required this.services,
    required this.runtime,
  });

  final ApplicationRepositoryDependencies repositories;
  final ApplicationServiceDependencies services;
  final ApplicationRuntimeDependencies runtime;
}

final class ApplicationServiceDependencies {
  const ApplicationServiceDependencies({
    required this.trialEvaluator,
  });

  final TrialEvaluator trialEvaluator;
}

final class ApplicationRepositoryDependencies {
  const ApplicationRepositoryDependencies({
    required this.auditLogReadRepository,
    required this.businessIdentityRepository,
    required this.documentHistoryRepository,
    required this.productCatalogReadRepository,
    required this.inventoryRepository,
    required this.saleRepository,
    required this.expenseRepository,
    required this.financialAccountRepository,
    required this.financialAccountCloudLinkResolver,
    required this.durableOutboxRepository,
    required this.durableInboxRepository,
    required this.durableConflictRepository,
    required this.durableSyncCheckpointRepository,
    required this.durableSyncTransactionCoordinator,
  });

  final AuditLogReadRepository auditLogReadRepository;
  final BusinessIdentityRepository businessIdentityRepository;
  final DocumentHistoryRepository documentHistoryRepository;
  final ProductCatalogReadRepository productCatalogReadRepository;
  final InventoryRepository inventoryRepository;
  final SaleRepository saleRepository;
  final ExpenseRepository expenseRepository;
  final FinancialAccountRepository financialAccountRepository;
  final FinancialAccountCloudLinkResolver financialAccountCloudLinkResolver;
  final DurableOutboxRepository durableOutboxRepository;
  final DurableInboxRepository durableInboxRepository;
  final DurableConflictRepository durableConflictRepository;
  final DurableSyncCheckpointRepository durableSyncCheckpointRepository;
  final DurableSyncTransactionCoordinator durableSyncTransactionCoordinator;
}

final class ApplicationRuntimeDependencies {
  const ApplicationRuntimeDependencies({
    required this.authController,
    required this.themeController,
    required this.businessIdentityController,
    required this.executionContextProvider,
    required this.deviceIdentity,
    required this.clock,
    required this.cloudModeEnabled,
    required this.sessionContextProvider,
    required this.businessContextProvider,
  });

  final AuthController authController;
  final ThemeController themeController;
  final BusinessIdentityController businessIdentityController;
  final ExecutionContextProvider executionContextProvider;
  final DeviceId deviceIdentity;
  final ApplicationClock clock;
  final bool cloudModeEnabled;
  final SessionContextProvider sessionContextProvider;
  final BusinessContextProvider businessContextProvider;
}
