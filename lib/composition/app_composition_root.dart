import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_expense_command.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_document_history_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';
import 'package:grain_warehouse_erp_lite/composition/legacy_application_dependency_bridge.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_cloud_session_adapter.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_runtime_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';

final class AppCompositionRoot {
  const AppCompositionRoot._();

  static SupabaseCloudSessionAdapter? _cloudSessionAdapter;

  static Future<ApplicationBoundary> initializeProduction({
    Future<FoundationDatabase> Function()? databaseFactory,
    TrialEvaluator? trialEvaluator,
    SupabaseRuntimeConfig? supabaseConfig,
    SupabaseClient? supabaseClient,
  }) async {
    await AppRepositories.initializeProduction(
      databaseFactory: databaseFactory,
    );

    final sharedTrialEvaluator =
        trialEvaluator ?? await TrialService.production();
    final configuredCloud = supabaseConfig ??
        (supabaseClient == null
            ? SupabaseRuntimeConfig.fromEnvironment()
            : null);
    SupabaseClient? activeSupabaseClient = supabaseClient;
    if (activeSupabaseClient == null && configuredCloud != null) {
      await Supabase.initialize(
        url: configuredCloud.url.toString(),
        publishableKey: configuredCloud.publishableKey,
      );
      activeSupabaseClient = Supabase.instance.client;
    }
    final localSessionContextProvider = LocalSessionContextProvider();
    final sessionSynchronizer = AuthSessionContextSynchronizer(
      provider: localSessionContextProvider,
    );
    final authController = AuthController(
      repository: AppRepositories.authRepository,
      onAuthenticatedUserChanged:
          activeSupabaseClient == null ? sessionSynchronizer.synchronize : null,
    );
    final themeController = ThemeController(
      repository: LocalThemeSettingsRepository(
        auditLogRepository: AppRepositories.auditLogRepository,
      ),
    );
    final sharedBusinessIdentityRepository =
        AppRepositories.businessIdentityRepository;
    final businessIdentityController = BusinessIdentityController(
      repository: sharedBusinessIdentityRepository,
    );
    SessionContextProvider sessionContextProvider = localSessionContextProvider;
    BusinessContextProvider businessContextProvider =
        const NoBusinessContextProvider();
    if (activeSupabaseClient != null) {
      final cloudAdapter = SupabaseCloudSessionAdapter(activeSupabaseClient);
      await cloudAdapter.initialize();
      _cloudSessionAdapter = cloudAdapter;
      sessionContextProvider = cloudAdapter.sessionContexts;
      businessContextProvider = cloudAdapter.businessContexts;
    }
    final financialAccountRepository =
        AppRepositories.financialAccountRepository;
    if (financialAccountRepository is! DriftFinancialAccountRepository) {
      throw StateError('Production financial account adapter is not durable.');
    }
    final attemptStore = DriftExpensePostingAttemptStore(
      AppRepositories.database,
      financialAccountRepository: financialAccountRepository,
    );
    final projectionWriter = DriftConfirmedExpenseProjectionWriter(
      AppRepositories.database,
      financialAccountRepository: financialAccountRepository,
    );
    final ExpensePostingGateway gateway = activeSupabaseClient == null
        ? const _UnavailableExpensePostingGateway()
        : SupabaseExpensePostingGateway(activeSupabaseClient);
    final dependencies =
        LegacyApplicationDependencyBridge.captureSharedInstances(
      trialEvaluator: sharedTrialEvaluator,
      authController: authController,
      themeController: themeController,
      businessIdentityController: businessIdentityController,
      businessIdentityRepository: sharedBusinessIdentityRepository,
      sessionContextProvider: sessionContextProvider,
      businessContextProvider: businessContextProvider,
      financialAccountCloudLinkResolver: attemptStore,
    );
    return ApplicationBoundary(
      dependencies: dependencies,
      commands: ApplicationCommands(
        trialEvaluation: EvaluateTrialCommandHandler(
          trialEvaluator: dependencies.services.trialEvaluator,
        ),
        postExpense: PostExpenseCommandHandler(
          sessionContextProvider: sessionContextProvider,
          businessContextProvider: businessContextProvider,
          attemptStore: attemptStore,
          gateway: gateway,
          projectionWriter: projectionWriter,
        ),
      ),
      queries: ApplicationQueries(
        auditLogs: LoadAuditLogsQueryHandler(
          repository: dependencies.repositories.auditLogReadRepository,
        ),
        businessLogo: LoadBusinessLogoQueryHandler(
          repository: dependencies.repositories.businessIdentityRepository,
        ),
        documentHistory: LoadDocumentHistoryQueryHandler(
          repository: dependencies.repositories.documentHistoryRepository,
        ),
        productCatalog: LoadProductCatalogQueryHandler(
          repository: dependencies.repositories.productCatalogReadRepository,
        ),
      ),
    );
  }

  static Future<void> close() async {
    await _cloudSessionAdapter?.dispose();
    _cloudSessionAdapter = null;
    await AppRepositories.close();
  }
}

final class _UnavailableExpensePostingGateway implements ExpensePostingGateway {
  const _UnavailableExpensePostingGateway();

  @override
  Future<ExpensePostingGatewayResponse> post(
    ExpensePostingRequestPayload payload,
  ) async =>
      const ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.authentication,
        code: 'unauthenticated.sessionRequired',
        retryable: false,
      );
}
