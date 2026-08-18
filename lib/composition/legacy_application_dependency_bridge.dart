import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_dependencies.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class LegacyApplicationDependencyBridge {
  const LegacyApplicationDependencyBridge._();

  static ApplicationDependencies captureSharedInstances({
    required TrialEvaluator trialEvaluator,
    required AuthController authController,
    required SessionContextProvider sessionContextProvider,
    required BusinessContextProvider businessContextProvider,
  }) {
    return ApplicationDependencies(
      repositories: ApplicationRepositoryDependencies(
        auditLogReadRepository: AppRepositories.auditLogRepository,
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
        sessionContextProvider: sessionContextProvider,
        businessContextProvider: businessContextProvider,
      ),
    );
  }
}
