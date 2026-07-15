import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class NegativeBalanceApprovalRepository {
  Future<NegativeBalanceApproval> createApproval(
    NegativeBalanceApprovalDraft draft,
  );

  Future<NegativeBalanceApproval> consumeApproval({
    required String approvalId,
    required String consumedByTransactionId,
  });

  /// Performs the full immutable binding check and marks a pending approval
  /// consumed as one repository operation. Callers must not use [findById] as
  /// an authorization decision.
  Future<NegativeBalanceApproval> consumeBoundApproval(
    NegativeBalanceApprovalBinding binding,
  );

  /// Reverts a just-consumed approval when its enclosing transaction fails.
  /// It is deliberately narrow: it only restores the exact transaction that
  /// consumed the approval.
  Future<void> restorePendingApproval({
    required String approvalId,
    required String consumedByTransactionId,
  });

  Future<NegativeBalanceApproval?> findById(String approvalId);

  Future<void> revokeApproval(String approvalId);

  Future<NegativeBalanceApproval?> findActiveApproval({
    required String accountId,
    required String requestedByUserId,
    required int amountQirsh,
  });

  Future<List<NegativeBalanceApproval>> listByAccount(String accountId);

  Future<List<NegativeBalanceApproval>> listAll();

  Future<void> restoreIntoEmpty(List<NegativeBalanceApproval> approvals);

  Future<void> clearForOwnerDataWipe();
}

class LocalNegativeBalanceApprovalRepository
    implements NegativeBalanceApprovalRepository, TransactionSnapshotProvider {
  LocalNegativeBalanceApprovalRepository();

  final List<NegativeBalanceApproval> _approvals = [];
  int _generatedIdCounter = 0;

  @override
  Future<NegativeBalanceApproval?> findById(String approvalId) async {
    final id = approvalId.trim();
    if (id.isEmpty) return null;
    for (final approval in _approvals) {
      if (approval.id == id) return approval;
    }
    return null;
  }

  @override
  Future<NegativeBalanceApproval> createApproval(
    NegativeBalanceApprovalDraft draft,
  ) async {
    _validateDraft(draft);

    final now = DateTime.now();
    final approval = NegativeBalanceApproval(
      id: _generateId(now),
      requestedByUserId: draft.requestedByUserId.trim(),
      approvedByOwnerUserId: draft.approvedByOwnerUserId.trim(),
      accountId: draft.accountId.trim(),
      amountQirsh: draft.amountQirsh,
      operationType: draft.operationType,
      sourceDocumentId: draft.sourceDocumentId.trim(),
      sourceDocumentType: draft.sourceDocumentType.trim(),
      balanceBeforeQirsh: draft.balanceBeforeQirsh,
      expectedBalanceAfterQirsh: draft.expectedBalanceAfterQirsh,
      createdAt: now,
      expiresAt: now.add(draft.duration),
      status: NegativeBalanceApprovalStatus.pending,
      reason: draft.reason,
      authorizationContext: draft.authorizationContext,
    );
    _approvals.add(approval);
    return approval;
  }

  @override
  Future<NegativeBalanceApproval> consumeApproval({
    required String approvalId,
    required String consumedByTransactionId,
  }) async {
    final id = approvalId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        approvalId,
        'approvalId',
        'Approval id is required.',
      );
    }
    final txnId = consumedByTransactionId.trim();
    if (txnId.isEmpty) {
      throw ArgumentError.value(
        consumedByTransactionId,
        'consumedByTransactionId',
        'Transaction id is required.',
      );
    }

    final index = _approvals.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw StateError('الموافقة غير موجودة.');
    }

    final approval = _approvals[index];
    if (approval.status != NegativeBalanceApprovalStatus.pending) {
      throw StateError(
          'الموافقة غير قابلة للاستخدام (الحالة: ${approval.status.labelAr}).');
    }
    if (approval.isExpired) {
      _approvals[index] = approval.copyWith(
        status: NegativeBalanceApprovalStatus.expired,
      );
      throw StateError('الموافقة منتهية الصلاحية.');
    }

    final now = DateTime.now();
    _approvals[index] = approval.copyWith(
      status: NegativeBalanceApprovalStatus.consumed,
      consumedAt: now,
      consumedByTransactionId: txnId,
    );

    return _approvals[index];
  }

  @override
  Future<NegativeBalanceApproval> consumeBoundApproval(
    NegativeBalanceApprovalBinding binding,
  ) async {
    binding.validate();
    final index =
        _approvals.indexWhere((value) => value.id == binding.approvalId);
    if (index < 0) throw StateError('الموافقة غير موجودة.');
    final approval = _approvals[index];
    if (approval.status != NegativeBalanceApprovalStatus.pending) {
      throw StateError('الموافقة غير قابلة للاستخدام.');
    }
    if (approval.isExpired) {
      _approvals[index] =
          approval.copyWith(status: NegativeBalanceApprovalStatus.expired);
      throw StateError('الموافقة منتهية الصلاحية.');
    }
    if (approval.accountId != binding.accountId ||
        approval.amountQirsh != binding.amountQirsh ||
        approval.operationType != binding.operationType ||
        approval.sourceDocumentId != binding.sourceDocumentId ||
        approval.sourceDocumentType != binding.sourceDocumentType ||
        approval.requestedByUserId != binding.requestedByUserId ||
        approval.balanceBeforeQirsh != binding.balanceBeforeQirsh ||
        approval.expectedBalanceAfterQirsh !=
            binding.expectedBalanceAfterQirsh ||
        !(approval.authorizationContext
                ?.matches(binding.authorizationContext) ??
            binding.authorizationContext == null)) {
      throw StateError('بيانات الموافقة لا تطابق العملية.');
    }
    return consumeApproval(
      approvalId: binding.approvalId,
      consumedByTransactionId: binding.transactionId,
    );
  }

  @override
  Future<void> restorePendingApproval({
    required String approvalId,
    required String consumedByTransactionId,
  }) async {
    final index =
        _approvals.indexWhere((value) => value.id == approvalId.trim());
    if (index < 0) throw StateError('الموافقة غير موجودة.');
    final approval = _approvals[index];
    if (approval.status != NegativeBalanceApprovalStatus.consumed ||
        approval.consumedByTransactionId != consumedByTransactionId.trim()) {
      throw StateError('لا يمكن استرجاع موافقة لا تخص العملية.');
    }
    _approvals[index] = NegativeBalanceApproval(
      id: approval.id,
      requestedByUserId: approval.requestedByUserId,
      approvedByOwnerUserId: approval.approvedByOwnerUserId,
      accountId: approval.accountId,
      amountQirsh: approval.amountQirsh,
      operationType: approval.operationType,
      sourceDocumentId: approval.sourceDocumentId,
      sourceDocumentType: approval.sourceDocumentType,
      balanceBeforeQirsh: approval.balanceBeforeQirsh,
      expectedBalanceAfterQirsh: approval.expectedBalanceAfterQirsh,
      createdAt: approval.createdAt,
      expiresAt: approval.expiresAt,
      status: NegativeBalanceApprovalStatus.pending,
      reason: approval.reason,
      authorizationContext: approval.authorizationContext,
    );
  }

  @override
  Future<void> revokeApproval(String approvalId) async {
    final id = approvalId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        approvalId,
        'approvalId',
        'Approval id is required.',
      );
    }

    final index = _approvals.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw StateError('الموافقة غير موجودة.');
    }

    final approval = _approvals[index];
    if (approval.status != NegativeBalanceApprovalStatus.pending) {
      throw StateError('لا يمكن إلغاء موافقة غير قيد الانتظار.');
    }

    _approvals[index] = approval.copyWith(
      status: NegativeBalanceApprovalStatus.revoked,
      revokedAt: DateTime.now(),
      revokedByUserId: approval.approvedByOwnerUserId,
    );
  }

  @override
  Future<NegativeBalanceApproval?> findActiveApproval({
    required String accountId,
    required String requestedByUserId,
    required int amountQirsh,
  }) async {
    final now = DateTime.now();
    for (final approval in _approvals) {
      if (approval.accountId == accountId &&
          approval.requestedByUserId == requestedByUserId &&
          approval.amountQirsh == amountQirsh &&
          approval.status == NegativeBalanceApprovalStatus.pending &&
          !now.isAfter(approval.expiresAt)) {
        return approval;
      }
    }
    return null;
  }

  @override
  Future<List<NegativeBalanceApproval>> listByAccount(
    String accountId,
  ) async {
    final filtered = _approvals
        .where((a) => a.accountId == accountId)
        .toList(growable: false);
    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<NegativeBalanceApproval>.unmodifiable(filtered);
  }

  @override
  Future<List<NegativeBalanceApproval>> listAll() async {
    final sorted = [..._approvals]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<NegativeBalanceApproval>.unmodifiable(sorted);
  }

  @override
  Future<void> restoreIntoEmpty(List<NegativeBalanceApproval> approvals) async {
    if (_approvals.isNotEmpty) {
      throw StateError('Negative balance approval repository is not empty.');
    }
    _validateUniqueRestoredApprovals(approvals);
    _approvals.addAll(approvals);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _approvals.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      ObjectStateSnapshot<(List<NegativeBalanceApproval>, int)>(
        captureState: () => (
          _approvals.map(_cloneApproval).toList(growable: true),
          _generatedIdCounter,
        ),
        restoreState: (state) {
          _approvals
            ..clear()
            ..addAll(state.$1);
          _generatedIdCounter = state.$2;
        },
      );

  NegativeBalanceApproval _cloneApproval(NegativeBalanceApproval value) =>
      NegativeBalanceApproval(
        id: value.id,
        requestedByUserId: value.requestedByUserId,
        approvedByOwnerUserId: value.approvedByOwnerUserId,
        accountId: value.accountId,
        amountQirsh: value.amountQirsh,
        operationType: value.operationType,
        sourceDocumentId: value.sourceDocumentId,
        sourceDocumentType: value.sourceDocumentType,
        balanceBeforeQirsh: value.balanceBeforeQirsh,
        expectedBalanceAfterQirsh: value.expectedBalanceAfterQirsh,
        reason: value.reason,
        authorizationContext: value.authorizationContext,
        createdAt: value.createdAt,
        expiresAt: value.expiresAt,
        status: value.status,
        consumedAt: value.consumedAt,
        consumedByTransactionId: value.consumedByTransactionId,
        revokedAt: value.revokedAt,
        revokedByUserId: value.revokedByUserId,
      );

  void _validateDraft(NegativeBalanceApprovalDraft draft) {
    if (draft.requestedByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.requestedByUserId,
        'requestedByUserId',
        'Requested by user id is required.',
      );
    }
    if (draft.approvedByOwnerUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.approvedByOwnerUserId,
        'approvedByOwnerUserId',
        'Approved by owner user id is required.',
      );
    }
    if (draft.accountId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.accountId,
        'accountId',
        'Account id is required.',
      );
    }
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(
        draft.amountQirsh,
        'amountQirsh',
        'Amount must be positive.',
      );
    }
    if (draft.sourceDocumentId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.sourceDocumentId,
        'sourceDocumentId',
        'Source document id is required.',
      );
    }
    if (draft.sourceDocumentType.trim().isEmpty) {
      throw ArgumentError.value(
        draft.sourceDocumentType,
        'sourceDocumentType',
        'Source document type is required.',
      );
    }
    if (draft.reason.trim().isEmpty) {
      throw ArgumentError.value(draft.reason, 'reason', 'Reason is required.');
    }
    if (draft.duration <= Duration.zero) {
      throw ArgumentError.value(
          draft.duration, 'duration', 'Duration must be positive.');
    }
    if (draft.operationType ==
            NegativeBalanceOperationType.customerAdvanceRefund &&
        (draft.authorizationContext == null ||
            draft.authorizationContext!.customerId.trim().isEmpty ||
            draft.authorizationContext!.advanceId.trim().isEmpty ||
            draft.authorizationContext!.financialDirection !=
                NegativeBalanceFinancialDirection.outflow)) {
      throw ArgumentError('بيانات ربط موافقة رد سلفة العميل مطلوبة.');
    }
  }

  void _validateUniqueRestoredApprovals(
      List<NegativeBalanceApproval> approvals) {
    final ids = <String>{};
    for (final approval in approvals) {
      if (!approval.hasValidId) {
        throw StateError('Invalid negative balance approval id.');
      }
      if (!ids.add(approval.id)) {
        throw StateError('Duplicate negative balance approval id.');
      }
    }
  }

  String _generateId(DateTime now) {
    _generatedIdCounter++;
    return 'nba-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }
}

class NegativeBalanceApprovalBinding {
  const NegativeBalanceApprovalBinding({
    required this.approvalId,
    required this.transactionId,
    required this.accountId,
    required this.amountQirsh,
    required this.operationType,
    required this.sourceDocumentId,
    required this.sourceDocumentType,
    required this.requestedByUserId,
    required this.balanceBeforeQirsh,
    required this.expectedBalanceAfterQirsh,
    this.authorizationContext,
  });

  final String approvalId;
  final String transactionId;
  final String accountId;
  final int amountQirsh;
  final NegativeBalanceOperationType operationType;
  final String sourceDocumentId;
  final String sourceDocumentType;
  final String requestedByUserId;
  final int balanceBeforeQirsh;
  final int expectedBalanceAfterQirsh;
  final NegativeBalanceApprovalContext? authorizationContext;

  void validate() {
    if (approvalId.trim().isEmpty ||
        transactionId.trim().isEmpty ||
        accountId.trim().isEmpty ||
        sourceDocumentId.trim().isEmpty ||
        sourceDocumentType.trim().isEmpty ||
        requestedByUserId.trim().isEmpty ||
        amountQirsh <= 0) {
      throw ArgumentError('A complete approval binding is required.');
    }
    if (operationType == NegativeBalanceOperationType.customerAdvanceRefund &&
        (authorizationContext == null ||
            authorizationContext!.customerId.trim().isEmpty ||
            authorizationContext!.advanceId.trim().isEmpty ||
            authorizationContext!.financialDirection !=
                NegativeBalanceFinancialDirection.outflow)) {
      throw ArgumentError('بيانات ربط موافقة رد سلفة العميل مطلوبة.');
    }
  }
}
