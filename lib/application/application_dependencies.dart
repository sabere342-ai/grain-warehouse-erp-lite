import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
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
  });

  final AuditLogReadRepository auditLogReadRepository;
  final BusinessIdentityRepository businessIdentityRepository;
  final DocumentHistoryRepository documentHistoryRepository;
  final ProductCatalogReadRepository productCatalogReadRepository;
  final InventoryRepository inventoryRepository;
  final SaleRepository saleRepository;
}

final class ApplicationRuntimeDependencies {
  const ApplicationRuntimeDependencies({
    required this.authController,
    required this.themeController,
    required this.businessIdentityController,
    required this.sessionContextProvider,
    required this.businessContextProvider,
  });

  final AuthController authController;
  final ThemeController themeController;
  final BusinessIdentityController businessIdentityController;
  final SessionContextProvider sessionContextProvider;
  final BusinessContextProvider businessContextProvider;
}
