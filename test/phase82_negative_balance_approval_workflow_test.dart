import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_workflow_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 82 durable negative-balance workflow', () {
    test('supplier and product revisions advance monotonically', () async {
      final supplierSeed = LocalSupplierRepository();
      final supplier = await supplierSeed.createSupplier(
        const SupplierDraft(name: 'مورد البصمة'),
      );
      final supplierFuture = supplier.updatedAt.add(const Duration(days: 1));
      final suppliers = LocalSupplierRepository();
      await suppliers.restoreSuppliersIntoEmpty([
        supplier.copyWith(updatedAt: supplierFuture),
      ]);
      final updatedSupplier = await suppliers.updateSupplier(
        supplierId: supplier.id,
        draft: const SupplierDraft(name: 'مورد البصمة المعدل'),
      );
      expect(updatedSupplier.updatedAt.isAfter(supplierFuture), isTrue);

      final productSeed = LocalProductRepository();
      final product = await productSeed.createProduct(
        const ProductDraft(name: 'صنف البصمة', unit: GrainUnit.kilogram),
      );
      final productFuture = product.updatedAt.add(const Duration(days: 1));
      final products = LocalProductRepository();
      await products.restoreProductsIntoEmpty([
        product.copyWith(updatedAt: productFuture),
      ]);
      final updatedProduct = await products.updateProduct(
        productId: product.id,
        draft: const ProductDraft(
          name: 'صنف البصمة المعدل',
          unit: GrainUnit.kilogram,
        ),
      );
      expect(updatedProduct.updatedAt.isAfter(productFuture), isTrue);
    });

    test(
        'all three operations create pending requests without business effects',
        () async {
      final fixture = await _Fixture.create();
      final baselineAudit =
          (await fixture.audit.exportStoredAuditLogs()).length;

      final supplierResult = await fixture.workflow.submitSupplierPayment(
        requester: fixture.owner,
        draft: fixture.supplierPayment('supplier-pending'),
      );
      final expenseResult = await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-pending', actor: fixture.employee),
      );
      final purchaseResult = await fixture.workflow.submitPurchase(
        requester: fixture.owner,
        draft: fixture.purchase('purchase-pending'),
      );

      expect(supplierResult.isPending, isTrue);
      expect(expenseResult.isPending, isTrue);
      expect(purchaseResult.isPending, isTrue);
      expect(await fixture.requests.listAll(), hasLength(3));
      expect(await fixture.supplierAccounts.listPayments(), isEmpty);
      expect(await fixture.expenses.listExpenses(), isEmpty);
      expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
      expect(
          await fixture.supplierAccounts
              .balanceForSupplier(fixture.supplier.id),
          2000);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          100);
      final newAudit =
          (await fixture.audit.exportStoredAuditLogs()).skip(0).where(
                (entry) =>
                    entry.actionType == 'negative_balance.request.created',
              );
      expect(newAudit, hasLength(3));
      expect(
          newAudit.every((entry) => entry.actorId?.isNotEmpty == true), isTrue);
      expect((await fixture.audit.exportStoredAuditLogs()).length,
          baselineAudit + 3);
    });

    test('sufficient balance executes directly and disallowed deficit rejects',
        () async {
      final sufficient = await _Fixture.create(openingBalanceQirsh: 1000);
      final executed = await sufficient.workflow.submitExpense(
        requester: sufficient.employee,
        draft: sufficient.expense('expense-direct', actor: sufficient.employee),
      );
      expect(executed.isPending, isFalse);
      expect(await sufficient.expenses.listExpenses(), hasLength(1));
      expect(await sufficient.requests.listAll(), isEmpty);
      expect(
        await sufficient.accounts
            .currentBalanceForAccount(sufficient.account.id),
        500,
      );

      final blocked = await _Fixture.create(allowNegative: false);
      await expectLater(
        blocked.workflow.submitExpense(
          requester: blocked.employee,
          draft: blocked.expense('expense-blocked', actor: blocked.employee),
        ),
        throwsStateError,
      );
      expect(await blocked.requests.listAll(), isEmpty);
      expect(await blocked.expenses.listExpenses(), isEmpty);
      expect(
          await blocked.accounts.currentBalanceForAccount(blocked.account.id),
          100);
    });

    test('idempotency replay is exact and duplicate pending is prevented',
        () async {
      final fixture = await _Fixture.create();
      final draft = fixture.expense('expense-idem', actor: fixture.employee);
      final first = await fixture.workflow
          .submitExpense(requester: fixture.employee, draft: draft);
      final replay = await fixture.workflow
          .submitExpense(requester: fixture.employee, draft: draft);
      expect(replay.request!.id, first.request!.id);
      expect(await fixture.requests.listAll(), hasLength(1));

      await expectLater(
        fixture.workflow.submitExpense(
          requester: fixture.employee,
          draft: ExpenseDraft(
            accountingClassification: ExpenseAccountingClassification.operating,
            date: draft.date,
            category: draft.category,
            amountQirsh: 600,
            createdByUserId: fixture.employee.id,
            financialAccountId: fixture.account.id,
            paymentMethod: PaymentMethod.cash,
            operationRequestId: 'expense-idem',
          ),
        ),
        throwsStateError,
      );
      final existing = first.request!;
      await expectLater(
        fixture.requests.createRequest(NegativeBalanceApprovalRequestDraft(
          idempotencyKey: 'different-idempotency-key',
          operationType: existing.operationType,
          financialAccountId: existing.financialAccountId,
          paymentMethod: existing.paymentMethod,
          amountQirsh: existing.amountQirsh,
          sourceDocumentId: existing.sourceDocumentId,
          payloadJson: existing.payloadJson,
          payloadFingerprint: existing.payloadFingerprint,
          requesterActorId: existing.requesterActorId,
          balanceAtRequestQirsh: existing.balanceAtRequestQirsh,
          expectedBalanceAtRequestQirsh: existing.expectedBalanceAtRequestQirsh,
          deficitAtRequestQirsh: existing.deficitAtRequestQirsh,
          reason: existing.reason,
        )),
        throwsStateError,
      );
      expect(await fixture.requests.listAll(), hasLength(1));
    });

    test('owner approval executes each operation once with real actor metadata',
        () async {
      final fixture = await _Fixture.create();
      final supplierRequest = (await fixture.workflow.submitSupplierPayment(
        requester: fixture.owner,
        draft: fixture.supplierPayment('supplier-execute'),
      ))
          .request!;
      final expenseRequest = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-execute', actor: fixture.employee),
      ))
          .request!;
      final purchaseRequest = (await fixture.workflow.submitPurchase(
        requester: fixture.owner,
        draft: fixture.purchase('purchase-execute'),
      ))
          .request!;

      for (final request in [
        supplierRequest,
        expenseRequest,
        purchaseRequest
      ]) {
        final resolved = await fixture.approve(request.id);
        expect(resolved.status, NegativeBalanceApprovalRequestStatus.executed);
        expect(resolved.resolverActorId, fixture.owner.id);
        expect(resolved.ownerVerificationReference, isNotEmpty);
        expect(resolved.resultDocumentId, isNotEmpty);
      }

      expect(await fixture.supplierAccounts.listPayments(), hasLength(1));
      expect(await fixture.expenses.listExpenses(), hasLength(1));
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 5);
      expect(
          await fixture.supplierAccounts
              .balanceForSupplier(fixture.supplier.id),
          1500);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          -1400);
      expect((await fixture.expenses.listExpenses()).single.createdByUserId,
          fixture.employee.id);
      expect(
          (await fixture.supplierAccounts.listPayments())
              .single
              .createdByUserId,
          fixture.owner.id);
      final purchase = (await fixture.purchases.listPurchaseIntakes()).single;
      expect(purchase.createdByUserId, fixture.owner.id);
      expect(purchase.outstandingAmountQirsh, 0);

      final replay = await fixture.approve(purchaseRequest.id);
      expect(replay.status, NegativeBalanceApprovalRequestStatus.executed);
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 5);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          -1400);
    });

    test('authorization and explicit self re-authentication fail closed',
        () async {
      final fixture = await _Fixture.create();
      final request = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-auth', actor: fixture.employee),
      ))
          .request!;

      await expectLater(
        fixture.workflow.approveAndExecute(
          requestId: request.id,
          approverActorId: fixture.employee.id,
          ownerPhone: fixture.employee.phone,
          ownerPassword: 'employee123',
        ),
        throwsStateError,
      );
      await expectLater(
        fixture.workflow.approveAndExecute(
          requestId: request.id,
          approverActorId: fixture.owner.id,
          ownerPhone: fixture.owner.phone,
          ownerPassword: 'wrong-password',
        ),
        throwsStateError,
      );
      expect((await fixture.requests.findById(request.id))!.status,
          NegativeBalanceApprovalRequestStatus.pending);
      expect(await fixture.expenses.listExpenses(), isEmpty);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          100);

      final ownerRequest = (await fixture.workflow.submitExpense(
        requester: fixture.owner,
        draft: fixture.expense('expense-owner-self', actor: fixture.owner),
      ))
          .request!;
      await expectLater(
        fixture.workflow.approveAndExecute(
          requestId: ownerRequest.id,
          approverActorId: fixture.owner.id,
          ownerPhone: fixture.owner.phone,
          ownerPassword: 'wrong-password',
        ),
        throwsStateError,
      );
      expect((await fixture.requests.findById(ownerRequest.id))!.status,
          NegativeBalanceApprovalRequestStatus.pending);
      expect((await fixture.approve(ownerRequest.id)).status,
          NegativeBalanceApprovalRequestStatus.executed);
    });

    test('balance change alone remains valid and sufficient balance executes',
        () async {
      final fixture = await _Fixture.create();
      final request = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-balance', actor: fixture.employee),
      ))
          .request!;
      await fixture.accounts.createEntry(
        accountId: fixture.account.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1000,
        sourceType: FinancialAccountEntrySource.manualCorrection,
        sourceDocumentId: 'balance-top-up',
        effectiveDate: DateTime(2026, 7, 2),
        createdByUserId: fixture.owner.id,
      );

      final executed = await fixture.approve(request.id);
      expect(executed.status, NegativeBalanceApprovalRequestStatus.executed);
      expect(await fixture.expenses.listExpenses(), hasLength(1));
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          600);
      expect(await fixture.legacyApprovals.listAll(), isEmpty);
    });

    test('material supplier, product, and account changes mark requests stale',
        () async {
      final supplierFixture = await _Fixture.create();
      final supplierRequest =
          (await supplierFixture.workflow.submitSupplierPayment(
        requester: supplierFixture.owner,
        draft: supplierFixture.supplierPayment('supplier-stale'),
      ))
              .request!;
      await supplierFixture.suppliers.updateSupplier(
        supplierId: supplierFixture.supplier.id,
        draft: const SupplierDraft(name: 'Changed supplier'),
      );
      final supplierStale = await supplierFixture.approve(supplierRequest.id);
      expect(supplierStale.status, NegativeBalanceApprovalRequestStatus.stale);
      expect(await supplierFixture.supplierAccounts.listPayments(), isEmpty);

      final productFixture = await _Fixture.create();
      final purchaseRequest = (await productFixture.workflow.submitPurchase(
        requester: productFixture.owner,
        draft: productFixture.purchase('purchase-stale'),
      ))
          .request!;
      await productFixture.products.updateProduct(
        productId: productFixture.product.id,
        draft: const ProductDraft(
          name: 'Changed product',
          unit: GrainUnit.kilogram,
        ),
      );
      final purchaseStale = await productFixture.approve(purchaseRequest.id);
      expect(purchaseStale.status, NegativeBalanceApprovalRequestStatus.stale);
      expect(await productFixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await productFixture.inventory.listAllMovements(), isEmpty);

      final accountFixture = await _Fixture.create();
      final expenseRequest = (await accountFixture.workflow.submitExpense(
        requester: accountFixture.employee,
        draft: accountFixture.expense('expense-account-stale',
            actor: accountFixture.employee),
      ))
          .request!;
      await accountFixture.accounts.deactivateAccount(
          accountFixture.account.id, accountFixture.owner.id);
      final accountStale = await accountFixture.approve(expenseRequest.id);
      expect(accountStale.status, NegativeBalanceApprovalRequestStatus.stale);
      expect(await accountFixture.expenses.listExpenses(), isEmpty);
    });

    test('reject and cancel are terminal and have no financial effects',
        () async {
      final fixture = await _Fixture.create();
      final rejectedRequest = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-reject', actor: fixture.employee),
      ))
          .request!;
      final rejected = await fixture.workflow.reject(
        requestId: rejectedRequest.id,
        actor: fixture.owner,
        reason: 'رفض اختباري',
      );
      expect(rejected.status, NegativeBalanceApprovalRequestStatus.rejected);
      await expectLater(fixture.approve(rejected.id), throwsStateError);

      final cancelledRequest = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-cancel', actor: fixture.employee),
      ))
          .request!;
      await expectLater(
        fixture.workflow.cancel(
          requestId: cancelledRequest.id,
          actor: fixture.owner,
          reason: 'forged cancellation',
        ),
        throwsStateError,
      );
      final cancelled = await fixture.workflow.cancel(
        requestId: cancelledRequest.id,
        actor: fixture.employee,
        reason: 'إلغاء من مقدم الطلب',
      );
      expect(cancelled.status, NegativeBalanceApprovalRequestStatus.cancelled);
      await expectLater(fixture.approve(cancelled.id), throwsStateError);
      expect(await fixture.expenses.listExpenses(), isEmpty);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          100);
    });

    test('concurrent approval executes once and terminal race has one winner',
        () async {
      final fixture = await _Fixture.create();
      final request = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-concurrent', actor: fixture.employee),
      ))
          .request!;
      final results = await Future.wait([
        fixture.approve(request.id),
        fixture.approve(request.id),
      ]);
      expect(
          results.every((value) =>
              value.status == NegativeBalanceApprovalRequestStatus.executed),
          isTrue);
      expect(await fixture.expenses.listExpenses(), hasLength(1));
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          -400);

      final raceRequest = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-race', actor: fixture.employee),
      ))
          .request!;
      final outcomes = await Future.wait<Object?>([
        _capture(fixture.approve(raceRequest.id)),
        _capture(fixture.workflow.reject(
          requestId: raceRequest.id,
          actor: fixture.owner,
          reason: 'race reject',
        )),
        _capture(fixture.workflow.cancel(
          requestId: raceRequest.id,
          actor: fixture.employee,
          reason: 'race cancel',
        )),
      ]);
      expect(
        outcomes.whereType<NegativeBalanceApprovalRequest>(),
        hasLength(1),
      );
      expect(
          (await fixture.requests.findById(raceRequest.id))!.status.isTerminal,
          isTrue);
    });

    test('failure after inventory/account mutation rolls everything back',
        () async {
      final audit = _ToggleFailAudit();
      final fixture = await _Fixture.create(audit: audit);
      final request = (await fixture.workflow.submitPurchase(
        requester: fixture.owner,
        draft: fixture.purchase('purchase-rollback'),
      ))
          .request!;
      final auditBefore = (await audit.exportStoredAuditLogs()).length;
      audit.failAction = 'purchase.created';

      await expectLater(fixture.approve(request.id), throwsStateError);
      expect((await fixture.requests.findById(request.id))!.status,
          NegativeBalanceApprovalRequestStatus.pending);
      expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 0);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          100);
      expect(
          await fixture.supplierAccounts
              .balanceForSupplier(fixture.supplier.id),
          2000);
      expect((await audit.exportStoredAuditLogs()).length, auditBefore);
    });

    test('durable transaction runner wraps request creation and execution',
        () async {
      final transactionRunner = _CountingTransactionRunner();
      final fixture = await _Fixture.create(
        durableTransactionRunner: transactionRunner.run,
      );
      final request = (await fixture.workflow.submitExpense(
        requester: fixture.owner,
        draft:
            fixture.expense('expense-durable-boundary', actor: fixture.owner),
      ))
          .request!;
      expect(transactionRunner.calls, 1);

      final executed = await fixture.approve(request.id);
      expect(executed.status, NegativeBalanceApprovalRequestStatus.executed);
      expect(transactionRunner.calls, 2);
      expect(await fixture.expenses.listExpenses(), hasLength(1));
    });

    test('durable repository restore preserves status, history, and identity',
        () async {
      final fixture = await _Fixture.create();
      final pending = (await fixture.workflow.submitExpense(
        requester: fixture.employee,
        draft: fixture.expense('expense-persist', actor: fixture.employee),
      ))
          .request!;
      final requests = await fixture.requests.listAll();
      final transitions = await fixture.requests.listTransitions();
      final reopened = LocalNegativeBalanceApprovalRequestRepository();
      await reopened.restoreIntoEmpty(
        requests: requests,
        transitions: transitions,
      );
      expect((await reopened.findById(pending.id))!.status,
          NegativeBalanceApprovalRequestStatus.pending);
      expect((await reopened.findById(pending.id))!.requesterActorId,
          fixture.employee.id);
      expect(
          await reopened.listTransitions(requestId: pending.id), hasLength(1));
    });
  });
}

Future<Object?> _capture(Future<Object?> operation) async {
  try {
    return await operation;
  } catch (error) {
    return error;
  }
}

class _Fixture {
  _Fixture({
    required this.audit,
    required this.auth,
    required this.owner,
    required this.employee,
    required this.legacyApprovals,
    required this.accounts,
    required this.account,
    required this.suppliers,
    required this.supplier,
    required this.products,
    required this.product,
    required this.inventory,
    required this.supplierAccounts,
    required this.expenses,
    required this.purchases,
    required this.requests,
    required this.workflow,
  });

  static Future<_Fixture> create({
    int openingBalanceQirsh = 100,
    bool allowNegative = true,
    _ToggleFailAudit? audit,
    DurableApprovalTransactionRunner? durableTransactionRunner,
  }) async {
    final actualAudit = audit ?? _ToggleFailAudit();
    final auth = LocalAuthRepository.demo();
    final owner = (await auth.getUserById('owner-demo'))!;
    final employee = (await auth.getUserById('employee-demo'))!;
    final legacyApprovals = LocalNegativeBalanceApprovalRepository();
    final legacyService = NegativeBalanceApprovalService(
      authRepository: auth,
      approvalRepository: legacyApprovals,
      auditLogRepository: actualAudit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: actualAudit,
      negativeBalanceApprovalService: legacyService,
    );
    final account = await accounts.createAccount(
      FinancialAccountDraft(
        name: 'Phase 82 treasury',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: allowNegative,
        createdByUserId: owner.id,
      ),
    );
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: openingBalanceQirsh,
      effectiveDate: DateTime(2026, 7, 1),
      createdByUserId: owner.id,
    );
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Phase 82 supplier'),
    );
    final products = LocalProductRepository();
    final product = await products.createProduct(
      const ProductDraft(name: 'Phase 82 grain', unit: GrainUnit.kilogram),
    );
    final inventory = LocalInventoryRepository(productRepository: products);
    final supplierAccounts = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: actualAudit,
      financialAccountRepository: accounts,
      negativeBalanceApprovalService: legacyService,
    );
    await supplierAccounts.createOpeningBalanceEntry(
      supplierId: supplier.id,
      amountQirsh: 2000,
      createdByUserId: owner.id,
    );
    final expenses = LocalExpenseRepository(
      auditLogRepository: actualAudit,
      financialAccountRepository: accounts,
    );
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      supplierAccountRepository: supplierAccounts,
      financialAccountRepository: accounts,
      auditLogRepository: actualAudit,
    );
    final requests = LocalNegativeBalanceApprovalRequestRepository();
    final workflow = NegativeBalanceApprovalWorkflowService(
      authRepository: auth,
      requestRepository: requests,
      legacyApprovalService: legacyService,
      auditLogRepository: actualAudit,
      financialAccountRepository: accounts,
      supplierRepository: suppliers,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      purchaseRepository: purchases,
      productRepository: products,
      inventoryRepository: inventory,
      durableTransactionRunner: durableTransactionRunner,
    );
    return _Fixture(
      audit: actualAudit,
      auth: auth,
      owner: owner,
      employee: employee,
      legacyApprovals: legacyApprovals,
      accounts: accounts,
      account: account,
      suppliers: suppliers,
      supplier: supplier,
      products: products,
      product: product,
      inventory: inventory,
      supplierAccounts: supplierAccounts,
      expenses: expenses,
      purchases: purchases,
      requests: requests,
      workflow: workflow,
    );
  }

  final _ToggleFailAudit audit;
  final LocalAuthRepository auth;
  final AppUser owner;
  final AppUser employee;
  final LocalNegativeBalanceApprovalRepository legacyApprovals;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;
  final LocalSupplierRepository suppliers;
  final Supplier supplier;
  final LocalProductRepository products;
  final Product product;
  final LocalInventoryRepository inventory;
  final LocalSupplierAccountRepository supplierAccounts;
  final LocalExpenseRepository expenses;
  final LocalPurchaseRepository purchases;
  final LocalNegativeBalanceApprovalRequestRepository requests;
  final NegativeBalanceApprovalWorkflowService workflow;

  SupplierPaymentDraft supplierPayment(String requestId) =>
      SupplierPaymentDraft(
        supplierId: supplier.id,
        date: DateTime(2026, 7, 2),
        amountQirsh: 500,
        createdByUserId: owner.id,
        createdByUserName: owner.name,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        operationRequestId: requestId,
      );

  ExpenseDraft expense(String requestId, {required AppUser actor}) =>
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime(2026, 7, 2),
        category: 'Utilities',
        amountQirsh: 500,
        createdByUserId: actor.id,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        operationRequestId: requestId,
      );

  PurchaseIntakeDraft purchase(String requestId) => PurchaseIntakeDraft(
        supplierId: supplier.id,
        productId: product.id,
        quantityKg: 5,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 100,
        createdByUserId: owner.id,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        paymentMode: PurchasePaymentMode.paid,
        paidAmountQirsh: 500,
        operationRequestId: requestId,
      );

  Future<NegativeBalanceApprovalRequest> approve(String requestId) =>
      workflow.approveAndExecute(
        requestId: requestId,
        approverActorId: owner.id,
        ownerPhone: owner.phone,
        ownerPassword: 'owner123',
      );
}

class _ToggleFailAudit extends LocalAuditLogRepository {
  String? failAction;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (draft.actionType == failAction) {
      throw StateError('Injected audit failure: ${draft.actionType}');
    }
    return super.record(draft);
  }
}

class _CountingTransactionRunner {
  int calls = 0;

  Future<Object?> run(Future<Object?> Function() operation) async {
    calls += 1;
    return operation();
  }
}
