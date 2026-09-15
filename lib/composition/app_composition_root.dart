import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_expense_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_internal_transfer_command.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/identity/device_identity_store.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_document_history_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_expenses_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/composition/legacy_application_dependency_bridge.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/cloud_hybrid_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_cloud_session_adapter.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_internal_transfer_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_product_catalog_gateways.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_runtime_config.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/local/file_device_identity_store.dart';
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
    DeviceIdentityStore? deviceIdentityStore,
    ApplicationClock? clock,
    SessionIdGenerator? sessionIdGenerator,
  }) async {
    await AppRepositories.initializeProduction(
      databaseFactory: databaseFactory,
    );

    final sharedClock = clock ?? const SystemApplicationClock();
    final sharedSessionIdGenerator =
        sessionIdGenerator ?? const UuidV4SessionIdGenerator();
    final resolvedDeviceStore =
        deviceIdentityStore ?? await FileDeviceIdentityStore.production();
    final deviceIdentity = await resolvedDeviceStore.loadOrProvision();
    final executionContextProvider = MutableExecutionContextProvider();
    final sessionContextProvider =
        ExecutionSessionContextProvider(executionContextProvider);
    final businessContextProvider =
        ExecutionBusinessContextProvider(executionContextProvider);

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
    final sessionSynchronizer = AuthSessionContextSynchronizer(
      provider: executionContextProvider,
      deviceIdentity: deviceIdentity,
      sessionIdGenerator: sharedSessionIdGenerator,
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
    final financialAccountRepository =
        AppRepositories.financialAccountRepository;
    if (financialAccountRepository is! DriftFinancialAccountRepository) {
      throw StateError('Production financial account adapter is not durable.');
    }
    final durableSyncStore = DriftDurableSyncStore(
      financialAccountRepository.database,
      clock: sharedClock,
    );
    final productSyncStore =
        DriftProductCatalogSyncStore(AppRepositories.database);
    final ProductCatalogPushGateway productPushGateway =
        activeSupabaseClient == null
            ? const UnavailableProductCatalogPushGateway()
            : SupabaseProductCatalogPushGateway(activeSupabaseClient);
    final ProductCatalogPullGateway productPullGateway =
        activeSupabaseClient == null
            ? const UnavailableProductCatalogPullGateway()
            : SupabaseProductCatalogPullGateway(activeSupabaseClient);
    final productSyncCoordinator = ProductCatalogSyncCoordinator(
      durableStore: durableSyncStore,
      productStore: productSyncStore,
      pushGateway: productPushGateway,
      pullGateway: productPullGateway,
      executionContexts: executionContextProvider,
      clock: sharedClock,
    );
    final localProductRepository = AppRepositories.productRepository;
    if (localProductRepository is! DriftProductRepository) {
      throw StateError('Production product adapter is not durable.');
    }
    AppRepositories.configureProductCatalog(
      productRepository: CloudHybridProductRepository(
        localRepository: localProductRepository,
        syncStore: productSyncStore,
        durableStore: durableSyncStore,
        executionContextProvider: executionContextProvider,
        clock: sharedClock,
        deviceIdentity: deviceIdentity,
        cloudModeEnabled: activeSupabaseClient != null,
        currentRemoteAuthUserId: () =>
            activeSupabaseClient?.auth.currentUser?.id,
        requestSync: productSyncCoordinator.synchronizeOnce,
      ),
      productCatalogReadRepository: DriftProductCatalogReadRepository(
        AppRepositories.database,
        clock: sharedClock,
      ),
    );
    if (activeSupabaseClient != null) {
      final cloudAdapter = SupabaseCloudSessionAdapter(
        activeSupabaseClient,
        executionContexts: executionContextProvider,
        deviceIdentity: deviceIdentity,
        sessionIdGenerator: sharedSessionIdGenerator,
        onVerifiedBusiness: (context) async {
          await productSyncStore.bindVerified(context, sharedClock.nowUtc());
          try {
            await productSyncCoordinator.synchronizeOnce();
          } on Object {
            // A verified session remains usable with durable offline work.
          }
        },
      );
      await cloudAdapter.initialize();
      _cloudSessionAdapter = cloudAdapter;
    }
    final attemptStore = DriftExpensePostingAttemptStore(
      AppRepositories.database,
      financialAccountRepository: financialAccountRepository,
      clock: sharedClock,
      durableSyncStore: durableSyncStore,
    );
    final projectionWriter = DriftConfirmedExpenseProjectionWriter(
      AppRepositories.database,
      financialAccountRepository: financialAccountRepository,
      clock: sharedClock,
      durableSyncStore: durableSyncStore,
    );
    final ExpensePostingGateway gateway = activeSupabaseClient == null
        ? const _UnavailableExpensePostingGateway()
        : SupabaseExpensePostingGateway(activeSupabaseClient);
    final transferAttemptStore = DriftInternalTransferPostingAttemptStore(
      AppRepositories.database,
      clock: sharedClock,
      durableSyncStore: durableSyncStore,
    );
    final transferProjectionWriter =
        DriftConfirmedInternalTransferProjectionWriter(
      AppRepositories.database,
      financialAccountRepository: financialAccountRepository,
      clock: sharedClock,
      durableSyncStore: durableSyncStore,
    );
    final InternalTransferPostingGateway transferGateway =
        activeSupabaseClient == null
            ? const _UnavailableInternalTransferPostingGateway()
            : SupabaseInternalTransferPostingGateway(activeSupabaseClient);
    final dependencies =
        LegacyApplicationDependencyBridge.captureSharedInstances(
      trialEvaluator: sharedTrialEvaluator,
      authController: authController,
      themeController: themeController,
      businessIdentityController: businessIdentityController,
      businessIdentityRepository: sharedBusinessIdentityRepository,
      executionContextProvider: executionContextProvider,
      deviceIdentity: deviceIdentity,
      clock: sharedClock,
      cloudModeEnabled: activeSupabaseClient != null,
      sessionContextProvider: sessionContextProvider,
      businessContextProvider: businessContextProvider,
      financialAccountCloudLinkResolver: attemptStore,
      durableSyncStore: durableSyncStore,
      productCatalogSyncCoordinator: productSyncCoordinator,
    );
    return ApplicationBoundary(
      dependencies: dependencies,
      commands: ApplicationCommands(
        trialEvaluation: EvaluateTrialCommandHandler(
          trialEvaluator: dependencies.services.trialEvaluator,
        ),
        postExpense: PostExpenseCommandHandler(
          executionContextProvider: executionContextProvider,
          attemptStore: attemptStore,
          gateway: gateway,
          projectionWriter: projectionWriter,
        ),
        postInternalTransfer: PostInternalTransferCommandHandler(
          executionContextProvider: executionContextProvider,
          attemptStore: transferAttemptStore,
          gateway: transferGateway,
          projectionWriter: transferProjectionWriter,
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
        expenses: LoadExpensesQueryHandler(
          repository: dependencies.repositories.expenseRepository,
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

final class _UnavailableInternalTransferPostingGateway
    implements InternalTransferPostingGateway {
  const _UnavailableInternalTransferPostingGateway();

  @override
  Future<InternalTransferPostingGatewayResponse> post(
    InternalTransferPostingRequestPayload payload,
  ) async =>
      const InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.authentication,
        code: 'unauthenticated.sessionRequired',
        retryable: false,
      );
}
