import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_dependencies.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class LegacyApplicationDependencyBridge {
  const LegacyApplicationDependencyBridge._();

  static ApplicationDependencies captureSharedInstances({
    required TrialEvaluator trialEvaluator,
    required AuthController authController,
    required ThemeController themeController,
    required BusinessIdentityController businessIdentityController,
    required BusinessIdentityRepository businessIdentityRepository,
    required SessionContextProvider sessionContextProvider,
    required BusinessContextProvider businessContextProvider,
  }) {
    return ApplicationDependencies(
      repositories: ApplicationRepositoryDependencies(
        auditLogReadRepository: AppRepositories.auditLogRepository,
        businessIdentityRepository: businessIdentityRepository,
        documentHistoryRepository: AppRepositories.documentHistoryRepository,
        productCatalogReadRepository:
            AppRepositories.productCatalogReadRepository,
        inventoryRepository: AppRepositories.inventoryRepository,
        saleRepository: AppRepositories.saleRepository,
      ),
      services: ApplicationServiceDependencies(
        trialEvaluator: trialEvaluator,
      ),
      runtime: ApplicationRuntimeDependencies(
        authController: authController,
        themeController: themeController,
        businessIdentityController: businessIdentityController,
        sessionContextProvider: sessionContextProvider,
        businessContextProvider: businessContextProvider,
      ),
    );
  }
}
