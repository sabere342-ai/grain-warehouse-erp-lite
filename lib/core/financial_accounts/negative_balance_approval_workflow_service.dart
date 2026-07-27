import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class NegativeBalanceSubmission<T> {
  const NegativeBalanceSubmission.executed(this.value) : request = null;
  const NegativeBalanceSubmission.pending(this.request) : value = null;

  final T? value;
  final NegativeBalanceApprovalRequest? request;
  bool get isPending => request != null;
}

typedef DurableApprovalTransactionRunner = Future<Object?> Function(
  Future<Object?> Function() operation,
);

class NegativeBalanceApprovalWorkflowService {
  NegativeBalanceApprovalWorkflowService({
    required AuthRepository authRepository,
    required DurableNegativeBalanceApprovalRequestRepository requestRepository,
    required NegativeBalanceApprovalService legacyApprovalService,
    required AuditLogRepository auditLogRepository,
    required FinancialAccountRepository financialAccountRepository,
    required SupplierRepository supplierRepository,
    required SupplierAccountRepository supplierAccountRepository,
    required ExpenseRepository expenseRepository,
    required PurchaseRepository purchaseRepository,
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
    DurableApprovalTransactionRunner? durableTransactionRunner,
  })  : _authRepository = authRepository,
        _requestRepository = requestRepository,
        _legacyApprovalService = legacyApprovalService,
        _auditLogRepository = auditLogRepository,
        _financialAccountRepository = financialAccountRepository,
        _supplierRepository = supplierRepository,
        _supplierAccountRepository = supplierAccountRepository,
        _expenseRepository = expenseRepository,
        _purchaseRepository = purchaseRepository,
        _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _durableTransactionRunner =
            durableTransactionRunner ?? _runWithoutDurableTransaction;

  final AuthRepository _authRepository;
  final DurableNegativeBalanceApprovalRequestRepository _requestRepository;
  final NegativeBalanceApprovalService _legacyApprovalService;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository _financialAccountRepository;
  final SupplierRepository _supplierRepository;
  final SupplierAccountRepository _supplierAccountRepository;
  final ExpenseRepository _expenseRepository;
  final PurchaseRepository _purchaseRepository;
  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final DurableApprovalTransactionRunner _durableTransactionRunner;

  NegativeBalanceApprovalRequestRepository get requests => _requestRepository;

  Future<NegativeBalanceSubmission<SupplierPaymentRecord>>
      submitSupplierPayment({
    required AppUser requester,
    required SupplierPaymentDraft draft,
    String reason = 'سداد مورد يتجاوز رصيد الحساب المالي',
  }) async {
    await _requireRequester(
      requester,
      NegativeBalanceApprovalRequestOperationType.supplierPayment,
    );
    if (draft.createdByUserId.trim() != requester.id) {
      throw StateError('هوية مقدم طلب سداد المورد لا تطابق منفذ العملية.');
    }
    final account = await _requireAccount(
      draft.financialAccountId,
      draft.paymentMethod,
    );
    final supplier = await _requireSupplier(draft.supplierId);
    if (draft.amountQirsh <= 0 ||
        draft.operationRequestId?.trim().isEmpty != false) {
      throw ArgumentError('بيانات سداد المورد أو معرف العملية غير صالحة.');
    }
    final supplierBalance =
        await _supplierAccountRepository.balanceForSupplier(supplier.id);
    if (supplierBalance <= 0 || draft.amountQirsh > supplierBalance) {
      throw StateError(
        'طلب الرصيد السالب لا يدمج سداد المورد مع سلفة أو زيادة دفع.',
      );
    }
    final balance =
        await _financialAccountRepository.currentBalanceForAccount(account.id);
    if (balance >= draft.amountQirsh) {
      return NegativeBalanceSubmission.executed(
        await _supplierAccountRepository.createPayment(draft),
      );
    }
    _requireNegativeRequestAllowed(account);
    final payload = <String, Object?>{
      ..._commonPayload(
        type: NegativeBalanceApprovalRequestOperationType.supplierPayment,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.amountQirsh,
        sourceDocumentId: draft.operationRequestId!,
        requesterActorId: requester.id,
      ),
      'supplierId': supplier.id,
      'supplierUpdatedAt': supplier.updatedAt.toUtc().toIso8601String(),
      'date': draft.date.toUtc().toIso8601String(),
      'notes': draft.notes?.trim(),
      'createdByUserName': draft.createdByUserName?.trim(),
    };
    return NegativeBalanceSubmission.pending(
      await _createRequest(
        type: NegativeBalanceApprovalRequestOperationType.supplierPayment,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.amountQirsh,
        sourceDocumentId: draft.operationRequestId!,
        relatedPartyId: supplier.id,
        requesterActorId: requester.id,
        balance: balance,
        reason: reason,
        payload: payload,
      ),
    );
  }

  Future<NegativeBalanceSubmission<ExpenseRecord>> submitExpense({
    required AppUser requester,
    required ExpenseDraft draft,
    String reason = 'مصروف يتجاوز رصيد الحساب المالي',
  }) async {
    await _requireRequester(
      requester,
      NegativeBalanceApprovalRequestOperationType.expense,
    );
    if (draft.createdByUserId.trim() != requester.id) {
      throw StateError('هوية مقدم المصروف لا تطابق منفذ العملية.');
    }
    final account = await _requireAccount(
      draft.financialAccountId,
      draft.paymentMethod,
    );
    if (draft.category.trim().isEmpty ||
        draft.amountQirsh <= 0 ||
        draft.operationRequestId.trim().isEmpty) {
      throw ArgumentError('بيانات المصروف أو معرف العملية غير صالحة.');
    }
    final balance =
        await _financialAccountRepository.currentBalanceForAccount(account.id);
    if (balance >= draft.amountQirsh) {
      return NegativeBalanceSubmission.executed(
        await _expenseRepository.createExpense(draft),
      );
    }
    _requireNegativeRequestAllowed(account);
    final payload = <String, Object?>{
      ..._commonPayload(
        type: NegativeBalanceApprovalRequestOperationType.expense,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.amountQirsh,
        sourceDocumentId: draft.operationRequestId,
        requesterActorId: requester.id,
      ),
      'date': draft.date.toUtc().toIso8601String(),
      'category': draft.category.trim(),
      'accountingClassification': draft.accountingClassification.name,
      'notes': draft.notes?.trim(),
    };
    return NegativeBalanceSubmission.pending(
      await _createRequest(
        type: NegativeBalanceApprovalRequestOperationType.expense,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.amountQirsh,
        sourceDocumentId: draft.operationRequestId,
        requesterActorId: requester.id,
        balance: balance,
        reason: reason,
        payload: payload,
      ),
    );
  }

  Future<NegativeBalanceSubmission<PurchaseIntake>> submitPurchase({
    required AppUser requester,
    required PurchaseIntakeDraft draft,
    String reason = 'شراء مدفوع يتجاوز رصيد الحساب المالي',
  }) async {
    await _requireRequester(
      requester,
      NegativeBalanceApprovalRequestOperationType.paidPurchase,
    );
    if (draft.createdByUserId.trim() != requester.id) {
      throw StateError('هوية مقدم الشراء لا تطابق منفذ العملية.');
    }
    if (draft.paymentMode == PurchasePaymentMode.credit) {
      return NegativeBalanceSubmission.executed(
        await _purchaseRepository.createPurchaseIntake(draft),
      );
    }
    if (draft.paymentMode != PurchasePaymentMode.paid ||
        draft.effectivePaidAmountQirsh != draft.totalAmountPiasters ||
        draft.operationRequestId?.trim().isEmpty != false) {
      throw ArgumentError('عقد الطلب الدائم يقبل شراء مدفوع بالكامل فقط.');
    }
    final account = await _requireAccount(
      draft.financialAccountId,
      draft.paymentMethod,
    );
    final supplier = await _requireSupplier(draft.supplierId);
    final product = await _requireProduct(draft.productId);
    if (draft.quantityKg <= 0 || draft.unitPricePiastersPerKg <= 0) {
      throw ArgumentError('كمية وسعر الشراء يجب أن يكونا موجبين.');
    }
    final balance =
        await _financialAccountRepository.currentBalanceForAccount(account.id);
    if (balance >= draft.totalAmountPiasters) {
      return NegativeBalanceSubmission.executed(
        await _purchaseRepository.createPurchaseIntake(draft),
      );
    }
    _requireNegativeRequestAllowed(account);
    final payload = <String, Object?>{
      ..._commonPayload(
        type: NegativeBalanceApprovalRequestOperationType.paidPurchase,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.totalAmountPiasters,
        sourceDocumentId: draft.operationRequestId!,
        requesterActorId: requester.id,
      ),
      'supplierId': supplier.id,
      'supplierUpdatedAt': supplier.updatedAt.toUtc().toIso8601String(),
      'supplierName': draft.supplierName,
      'supplierPhone': draft.supplierPhone,
      'supplierAddress': draft.supplierAddress,
      'productId': product.id,
      'productUpdatedAt': product.updatedAt.toUtc().toIso8601String(),
      'quantityKg': draft.quantityKg,
      'entryUnit': draft.entryUnit.name,
      'unitPricePiastersPerKg': draft.unitPricePiastersPerKg,
      'notes': draft.notes,
    };
    return NegativeBalanceSubmission.pending(
      await _createRequest(
        type: NegativeBalanceApprovalRequestOperationType.paidPurchase,
        account: account,
        method: draft.paymentMethod!,
        amountQirsh: draft.totalAmountPiasters,
        sourceDocumentId: draft.operationRequestId!,
        relatedPartyId: supplier.id,
        requesterActorId: requester.id,
        balance: balance,
        reason: reason,
        payload: payload,
      ),
    );
  }

  Future<NegativeBalanceApprovalRequest> approveAndExecute({
    required String requestId,
    required String approverActorId,
    required String ownerPhone,
    required String ownerPassword,
  }) async {
    final owner = await _authRepository.verifyCredentials(
      phone: ownerPhone,
      password: ownerPassword,
    );
    if (owner == null ||
        !owner.canProceed ||
        owner.role != UserRole.owner ||
        owner.id != approverActorId.trim()) {
      throw StateError('تعذر إعادة إثبات هوية المالك المنفذ.');
    }
    final initial = await _requireRequest(requestId);
    if (initial.status == NegativeBalanceApprovalRequestStatus.executed) {
      return initial;
    }
    if (initial.status != NegativeBalanceApprovalRequestStatus.pending) {
      throw StateError('لا يمكن تنفيذ طلب موافقة نهائي.');
    }
    final verificationReference = sha256
        .convert(utf8.encode(
          '${initial.id}|${owner.id}|${DateTime.now().microsecondsSinceEpoch}',
        ))
        .toString();

    return _runDurably(
      () => RepositoryTransaction.execute(_executionSnapshots(), () async {
        final request = await _requireRequest(initial.id);
        if (request.status == NegativeBalanceApprovalRequestStatus.executed) {
          return request;
        }
        if (request.status != NegativeBalanceApprovalRequestStatus.pending) {
          throw StateError('سبق حسم طلب الموافقة.');
        }
        final activeOwner = await _authRepository.getUserById(owner.id);
        if (activeOwner == null ||
            !activeOwner.canProceed ||
            activeOwner.role != UserRole.owner) {
          throw StateError('المالك المنفذ لم يعد نشطًا.');
        }
        final staleReason = await _staleReason(request);
        if (staleReason != null) {
          final stale = await _requestRepository.resolveRequest(
            requestId: request.id,
            status: NegativeBalanceApprovalRequestStatus.stale,
            resolverActorId: owner.id,
            reason: staleReason,
          );
          await _recordResolutionAudit(stale, owner.id, 'stale');
          return stale;
        }

        final currentBalance = await _financialAccountRepository
            .currentBalanceForAccount(request.financialAccountId);
        String? legacyApprovalId;
        if (currentBalance < request.amountQirsh) {
          legacyApprovalId = await _legacyApprovalService.requestApproval(
            draft: NegativeBalanceApprovalDraft(
              requestedByUserId: request.requesterActorId,
              approvedByOwnerUserId: owner.id,
              accountId: request.financialAccountId,
              amountQirsh: request.amountQirsh,
              operationType: _legacyOperationType(request.operationType),
              sourceDocumentId: request.sourceDocumentId,
              sourceDocumentType: _financialSource(request.operationType).name,
              balanceBeforeQirsh: currentBalance,
              expectedBalanceAfterQirsh: currentBalance - request.amountQirsh,
              reason: request.reason,
            ),
            ownerPhone: ownerPhone,
            ownerPassword: ownerPassword,
          );
        }
        final resultId = await _executeOperation(
          request,
          owner.id,
          legacyApprovalId,
        );
        final executed = await _requestRepository.resolveRequest(
          requestId: request.id,
          status: NegativeBalanceApprovalRequestStatus.executed,
          resolverActorId: owner.id,
          reason: 'تم اعتماد الطلب وتنفيذ العملية ذريًا.',
          ownerVerificationReference: verificationReference,
          resultDocumentId: resultId,
        );
        await _recordResolutionAudit(executed, owner.id, 'executed');
        return executed;
      }),
    );
  }

  Future<NegativeBalanceApprovalRequest> reject({
    required String requestId,
    required AppUser actor,
    required String reason,
  }) async {
    return _resolveWithoutFinancialEffect(
      requestId: requestId,
      actor: actor,
      status: NegativeBalanceApprovalRequestStatus.rejected,
      reason: reason,
      requireOwner: true,
    );
  }

  Future<NegativeBalanceApprovalRequest> cancel({
    required String requestId,
    required AppUser actor,
    required String reason,
  }) async {
    return _resolveWithoutFinancialEffect(
      requestId: requestId,
      actor: actor,
      status: NegativeBalanceApprovalRequestStatus.cancelled,
      reason: reason,
      requireOwner: false,
    );
  }

  Future<NegativeBalanceApprovalRequest> _resolveWithoutFinancialEffect({
    required String requestId,
    required AppUser actor,
    required NegativeBalanceApprovalRequestStatus status,
    required String reason,
    required bool requireOwner,
  }) =>
      _runDurably(
        () => RepositoryTransaction.execute(
          [_snapshot(_requestRepository), _snapshot(_auditLogRepository)],
          () async {
            final request = await _requireRequest(requestId);
            final storedActor = await _authRepository.getUserById(actor.id);
            if (storedActor == null || !storedActor.canProceed) {
              throw StateError('هوية منفذ حسم الطلب غير صالحة.');
            }
            if (requireOwner && storedActor.role != UserRole.owner) {
              throw StateError('رفض طلب الموافقة متاح للمالك فقط.');
            }
            if (!requireOwner && request.requesterActorId != storedActor.id) {
              throw StateError('إلغاء الطلب متاح لمقدم الطلب فقط.');
            }
            if (request.status !=
                NegativeBalanceApprovalRequestStatus.pending) {
              throw StateError('سبق حسم طلب الموافقة.');
            }
            final resolved = await _requestRepository.resolveRequest(
              requestId: request.id,
              status: status,
              resolverActorId: storedActor.id,
              reason: _requiredReason(reason),
            );
            await _recordResolutionAudit(
              resolved,
              storedActor.id,
              status.name,
            );
            return resolved;
          },
        ),
      );

  Future<NegativeBalanceApprovalRequest> _createRequest({
    required NegativeBalanceApprovalRequestOperationType type,
    required FinancialAccount account,
    required PaymentMethod method,
    required int amountQirsh,
    required String sourceDocumentId,
    required String requesterActorId,
    required int balance,
    required String reason,
    required Map<String, Object?> payload,
    String? relatedPartyId,
  }) async {
    final payloadJson = jsonEncode(_canonicalJson(payload));
    final fingerprint = sha256.convert(utf8.encode(payloadJson)).toString();
    return _runDurably(
      () => RepositoryTransaction.execute(
        [_snapshot(_requestRepository), _snapshot(_auditLogRepository)],
        () async {
          final request = await _requestRepository.createRequest(
            NegativeBalanceApprovalRequestDraft(
              idempotencyKey: sourceDocumentId,
              operationType: type,
              financialAccountId: account.id,
              paymentMethod: method,
              amountQirsh: amountQirsh,
              sourceDocumentId: sourceDocumentId,
              payloadJson: payloadJson,
              payloadFingerprint: fingerprint,
              relatedPartyId: relatedPartyId,
              requesterActorId: requesterActorId,
              balanceAtRequestQirsh: balance,
              expectedBalanceAtRequestQirsh: balance - amountQirsh,
              deficitAtRequestQirsh: amountQirsh - balance,
              reason: _requiredReason(reason),
            ),
          );
          final existingAudit = (await _auditLogRepository.listLogs()).any(
            (entry) =>
                entry.actionType == 'negative_balance.request.created' &&
                entry.referenceId == request.id,
          );
          if (!existingAudit) {
            await _auditLogRepository.record(AuditLogDraft(
              actionType: 'negative_balance.request.created',
              descriptionAr: 'تم إنشاء طلب موافقة دون تنفيذ العملية المالية.',
              actorId: requesterActorId,
              referenceId: request.id,
              metadata: _auditMetadata(request, requesterActorId),
            ));
          }
          return request;
        },
      ),
    );
  }

  Future<String?> _staleReason(
    NegativeBalanceApprovalRequest request,
  ) async {
    final fingerprint =
        sha256.convert(utf8.encode(request.payloadJson)).toString();
    if (fingerprint != request.payloadFingerprint) {
      return 'تغيرت البصمة المالية للطلب.';
    }
    final payload = _decodePayload(request.payloadJson);
    if (payload['operationType'] != request.operationType.name ||
        payload['sourceDocumentId'] != request.sourceDocumentId ||
        payload['financialAccountId'] != request.financialAccountId ||
        payload['paymentMethod'] != request.paymentMethod.name ||
        payload['amountQirsh'] != request.amountQirsh ||
        payload['requesterActorId'] != request.requesterActorId) {
      return 'لا تطابق بيانات الطلب المالية السجل الدائم.';
    }
    final requester =
        await _authRepository.getUserById(request.requesterActorId);
    if (requester == null ||
        !requester.canProceed ||
        !_hasOperationPermission(requester, request.operationType)) {
      return 'فقد مقدم الطلب صلاحية العملية.';
    }
    FinancialAccount account;
    try {
      account = await _financialAccountRepository
          .accountById(request.financialAccountId);
    } on Object {
      return 'الحساب المالي لم يعد موجودًا.';
    }
    if (!account.isActive) return 'الحساب المالي لم يعد نشطًا.';
    if (payload['accountType'] != account.type.name ||
        !PaymentRoutingPolicy.isCompatible(
          paymentMethod: request.paymentMethod,
          accountType: account.type,
        )) {
      return 'تغير نوع الحساب أو توافق طريقة الدفع.';
    }
    final balance =
        await _financialAccountRepository.currentBalanceForAccount(account.id);
    if (balance < request.amountQirsh && !account.allowNegativeBalance) {
      return 'تم إيقاف سياسة السماح بالرصيد السالب للحساب.';
    }
    switch (request.operationType) {
      case NegativeBalanceApprovalRequestOperationType.supplierPayment:
        final supplier = await _findSupplier(payload['supplierId'] as String?);
        if (supplier == null ||
            !supplier.isActive ||
            payload['supplierUpdatedAt'] !=
                supplier.updatedAt.toUtc().toIso8601String()) {
          return 'تغيرت بيانات المورد المرتبطة بالطلب.';
        }
        final payable =
            await _supplierAccountRepository.balanceForSupplier(supplier.id);
        if (payable < request.amountQirsh) {
          return 'تغير رصيد المورد بما يغير طبيعة السداد.';
        }
      case NegativeBalanceApprovalRequestOperationType.expense:
        if ((payload['category'] as String?)?.trim().isEmpty != false ||
            DateTime.tryParse(payload['date'] as String? ?? '') == null ||
            !ExpenseAccountingClassification.values.any(
              (value) => value.name == payload['accountingClassification'],
            )) {
          return 'بيانات المصروف الدائمة غير صالحة.';
        }
      case NegativeBalanceApprovalRequestOperationType.paidPurchase:
        final supplier = await _findSupplier(payload['supplierId'] as String?);
        final product = await _findProduct(payload['productId'] as String?);
        if (supplier == null ||
            !supplier.isActive ||
            payload['supplierUpdatedAt'] !=
                supplier.updatedAt.toUtc().toIso8601String()) {
          return 'تغيرت بيانات مورد الشراء.';
        }
        if (product == null ||
            !product.isActive ||
            payload['productUpdatedAt'] !=
                product.updatedAt.toUtc().toIso8601String()) {
          return 'تغيرت بيانات صنف الشراء.';
        }
        final quantity = payload['quantityKg'];
        final unitPrice = payload['unitPricePiastersPerKg'];
        if (quantity is! int ||
            quantity <= 0 ||
            unitPrice is! int ||
            unitPrice <= 0 ||
            quantity * unitPrice != request.amountQirsh) {
          return 'تغيرت بنود أو إجمالي الشراء.';
        }
    }
    return null;
  }

  Future<String> _executeOperation(
    NegativeBalanceApprovalRequest request,
    String resolverActorId,
    String? legacyApprovalId,
  ) async {
    final payload = _decodePayload(request.payloadJson);
    switch (request.operationType) {
      case NegativeBalanceApprovalRequestOperationType.supplierPayment:
        final value = await _supplierAccountRepository.createPayment(
          SupplierPaymentDraft(
            supplierId: payload['supplierId'] as String,
            date: DateTime.parse(payload['date'] as String),
            amountQirsh: request.amountQirsh,
            createdByUserId: request.requesterActorId,
            createdByUserName: payload['createdByUserName'] as String?,
            notes: payload['notes'] as String?,
            financialAccountId: request.financialAccountId,
            paymentMethod: request.paymentMethod,
            approvedByUserId: resolverActorId,
            negativeBalanceApprovalId: legacyApprovalId,
            operationRequestId: request.sourceDocumentId,
          ),
        );
        return value.id;
      case NegativeBalanceApprovalRequestOperationType.expense:
        final value = await _expenseRepository.createExpense(
          ExpenseDraft(
            accountingClassification: ExpenseAccountingClassification.values
                .byName(payload['accountingClassification'] as String),
            date: DateTime.parse(payload['date'] as String),
            category: payload['category'] as String,
            amountQirsh: request.amountQirsh,
            createdByUserId: request.requesterActorId,
            notes: payload['notes'] as String?,
            financialAccountId: request.financialAccountId,
            paymentMethod: request.paymentMethod,
            approvedByUserId: resolverActorId,
            negativeBalanceApprovalId: legacyApprovalId,
            operationRequestId: request.sourceDocumentId,
          ),
        );
        return value.id;
      case NegativeBalanceApprovalRequestOperationType.paidPurchase:
        final value = await _purchaseRepository.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: payload['supplierId'] as String,
            supplierName: payload['supplierName'] as String?,
            supplierPhone: payload['supplierPhone'] as String?,
            supplierAddress: payload['supplierAddress'] as String?,
            productId: payload['productId'] as String,
            quantityKg: payload['quantityKg'] as int,
            entryUnit: GrainUnit.values.firstWhere(
              (value) => value.name == payload['entryUnit'],
            ),
            unitPricePiastersPerKg: payload['unitPricePiastersPerKg'] as int,
            createdByUserId: request.requesterActorId,
            notes: payload['notes'] as String?,
            financialAccountId: request.financialAccountId,
            paymentMethod: request.paymentMethod,
            paymentMode: PurchasePaymentMode.paid,
            paidAmountQirsh: request.amountQirsh,
            approvedByUserId: resolverActorId,
            negativeBalanceApprovalId: legacyApprovalId,
            operationRequestId: request.sourceDocumentId,
          ),
        );
        return value.id;
    }
  }

  List<SnapshotHolder> _executionSnapshots() => [
        _snapshot(_requestRepository),
        _legacyApprovalService.createTransactionSnapshot(),
        _snapshot(_auditLogRepository),
        _snapshot(_financialAccountRepository),
        _snapshot(_supplierAccountRepository),
        _snapshot(_expenseRepository),
        _snapshot(_purchaseRepository),
        _snapshot(_inventoryRepository),
      ];

  SnapshotHolder _snapshot(Object repository) {
    if (repository is! TransactionSnapshotProvider) {
      throw StateError(
          'Repository cannot participate in approval transaction.');
    }
    return repository.createTransactionSnapshot();
  }

  Future<void> _requireRequester(
    AppUser requester,
    NegativeBalanceApprovalRequestOperationType type,
  ) async {
    final stored = await _authRepository.getUserById(requester.id);
    if (stored == null ||
        !stored.canProceed ||
        !_hasOperationPermission(stored, type)) {
      throw StateError('المستخدم لا يملك صلاحية إنشاء هذه العملية.');
    }
  }

  bool _hasOperationPermission(
    AppUser user,
    NegativeBalanceApprovalRequestOperationType type,
  ) =>
      switch (type) {
        NegativeBalanceApprovalRequestOperationType.supplierPayment =>
          user.permissions.canCreateSupplierPayment,
        NegativeBalanceApprovalRequestOperationType.expense =>
          user.permissions.canCreateExpense,
        NegativeBalanceApprovalRequestOperationType.paidPurchase =>
          user.permissions.canCreatePurchaseIntake,
      };

  Future<FinancialAccount> _requireAccount(
    String? accountId,
    PaymentMethod? method,
  ) async {
    if (accountId?.trim().isEmpty != false || method == null) {
      throw StateError('طريقة الدفع والحساب المالي مطلوبان.');
    }
    final account =
        await _financialAccountRepository.accountById(accountId!.trim());
    PaymentRoutingPolicy.validateAccount(
        account: account, paymentMethod: method);
    return account;
  }

  void _requireNegativeRequestAllowed(FinancialAccount account) {
    if (!account.allowNegativeBalance) {
      throw StateError('الحساب لا يسمح بطلب تجاوز الرصيد السالب.');
    }
  }

  Future<Supplier> _requireSupplier(String id) async {
    final supplier = await _findSupplier(id);
    if (supplier == null || !supplier.isActive) {
      throw StateError('المورد غير موجود أو غير نشط.');
    }
    return supplier;
  }

  Future<Product> _requireProduct(String id) async {
    final product = await _findProduct(id);
    if (product == null || !product.isActive) {
      throw StateError('الصنف غير موجود أو غير نشط.');
    }
    return product;
  }

  Future<Supplier?> _findSupplier(String? id) async {
    if (id?.trim().isEmpty != false) return null;
    for (final value
        in await _supplierRepository.listSuppliers(includeInactive: true)) {
      if (value.id == id!.trim()) return value;
    }
    return null;
  }

  Future<Product?> _findProduct(String? id) async {
    if (id?.trim().isEmpty != false) return null;
    for (final value
        in await _productRepository.listProducts(includeInactive: true)) {
      if (value.id == id!.trim()) return value;
    }
    return null;
  }

  Future<NegativeBalanceApprovalRequest> _requireRequest(String id) async {
    final request = await _requestRepository.findById(id.trim());
    if (request == null) throw StateError('طلب الموافقة غير موجود.');
    return request;
  }

  Map<String, Object?> _commonPayload({
    required NegativeBalanceApprovalRequestOperationType type,
    required FinancialAccount account,
    required PaymentMethod method,
    required int amountQirsh,
    required String sourceDocumentId,
    required String requesterActorId,
  }) =>
      <String, Object?>{
        'operationType': type.name,
        'sourceDocumentId': sourceDocumentId.trim(),
        'financialAccountId': account.id,
        'accountType': account.type.name,
        'paymentMethod': method.name,
        'amountQirsh': amountQirsh,
        'requesterActorId': requesterActorId.trim(),
      };

  Map<String, Object?> _decodePayload(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
          'Approval request payload must be an object.');
    }
    return value.cast<String, Object?>();
  }

  Object? _canonicalJson(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List<Object?>) return value.map(_canonicalJson).toList();
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalJson(value[key]),
      };
    }
    throw ArgumentError('Approval payload contains a non-JSON value.');
  }

  NegativeBalanceOperationType _legacyOperationType(
    NegativeBalanceApprovalRequestOperationType type,
  ) =>
      switch (type) {
        NegativeBalanceApprovalRequestOperationType.supplierPayment =>
          NegativeBalanceOperationType.supplierPayment,
        NegativeBalanceApprovalRequestOperationType.expense =>
          NegativeBalanceOperationType.expense,
        NegativeBalanceApprovalRequestOperationType.paidPurchase =>
          NegativeBalanceOperationType.purchasePayment,
      };

  FinancialAccountEntrySource _financialSource(
    NegativeBalanceApprovalRequestOperationType type,
  ) =>
      switch (type) {
        NegativeBalanceApprovalRequestOperationType.supplierPayment =>
          FinancialAccountEntrySource.supplierSettlement,
        NegativeBalanceApprovalRequestOperationType.expense =>
          FinancialAccountEntrySource.expense,
        NegativeBalanceApprovalRequestOperationType.paidPurchase =>
          FinancialAccountEntrySource.purchasePayment,
      };

  Future<void> _recordResolutionAudit(
    NegativeBalanceApprovalRequest request,
    String actorId,
    String result,
  ) =>
      _auditLogRepository.record(AuditLogDraft(
        actionType: 'negative_balance.request.$result',
        descriptionAr:
            'تم حسم طلب موافقة الرصيد السالب بالحالة ${request.status.labelAr}.',
        actorId: actorId,
        referenceId: request.id,
        metadata: _auditMetadata(request, actorId),
      ));

  Map<String, Object?> _auditMetadata(
    NegativeBalanceApprovalRequest request,
    String actorId,
  ) =>
      <String, Object?>{
        'requestId': request.id,
        'operationType': request.operationType.name,
        'status': request.status.name,
        'actorId': actorId,
        'requesterActorId': request.requesterActorId,
        'resolverActorId': request.resolverActorId,
        'accountId': request.financialAccountId,
        'amountQirsh': request.amountQirsh,
        'payloadFingerprint': request.payloadFingerprint,
      };

  String _requiredReason(String value) {
    final reason = value.trim();
    if (reason.isEmpty) throw ArgumentError('سبب حسم الطلب مطلوب.');
    return reason;
  }

  Future<T> _runDurably<T>(Future<T> Function() operation) async =>
      await _durableTransactionRunner(operation) as T;

  static Future<Object?> _runWithoutDurableTransaction(
    Future<Object?> Function() operation,
  ) =>
      operation();
}
