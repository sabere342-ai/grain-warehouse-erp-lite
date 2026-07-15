import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

/// Creates and consumes one-time approvals. Credentials are only accepted by
/// [requestApproval] and are never retained by this service or its records.
class NegativeBalanceApprovalService {
  NegativeBalanceApprovalService({
    required AuthRepository authRepository,
    required NegativeBalanceApprovalRepository approvalRepository,
    required AuditLogRepository auditLogRepository,
  })  : _authRepository = authRepository,
        _approvalRepository = approvalRepository,
        _auditLogRepository = auditLogRepository;

  final AuthRepository _authRepository;
  final NegativeBalanceApprovalRepository _approvalRepository;
  final AuditLogRepository _auditLogRepository;

  SnapshotHolder createTransactionSnapshot() {
    final repository = _approvalRepository;
    if (repository is! TransactionSnapshotProvider) {
      throw StateError('مستودع الموافقات لا يدعم المعاملات الذرية.');
    }
    final snapshots = <SnapshotHolder>[
      (repository as TransactionSnapshotProvider).createTransactionSnapshot(),
    ];
    final audit = _auditLogRepository;
    if (audit is TransactionSnapshotProvider) {
      snapshots.add(
        (audit as TransactionSnapshotProvider).createTransactionSnapshot(),
      );
    } else {
      throw StateError('مستودع التدقيق لا يدعم المعاملات الذرية.');
    }
    return CompositeSnapshot(snapshots);
  }

  Future<String> requestApproval({
    required NegativeBalanceApprovalDraft draft,
    required String ownerPhone,
    required String ownerPassword,
  }) async {
    if (draft.operationType.requiresNegativeBalance &&
        draft.expectedBalanceAfterQirsh >= 0) {
      throw StateError('لا يلزم اعتماد رصيد سالب لهذه العملية.');
    }
    final owner = await _authRepository.verifyCredentials(
      phone: ownerPhone,
      password: ownerPassword,
    );
    if (owner == null || !owner.canProceed || owner.role != UserRole.owner) {
      throw StateError('تعذر التحقق من بيانات مالك نشط.');
    }
    // The authenticated owner is authoritative. A user id supplied by the UI
    // is never accepted as evidence of an approval.
    final approval = await _approvalRepository.createApproval(
      NegativeBalanceApprovalDraft(
        requestedByUserId: draft.requestedByUserId,
        approvedByOwnerUserId: owner.id,
        accountId: draft.accountId,
        amountQirsh: draft.amountQirsh,
        operationType: draft.operationType,
        sourceDocumentId: draft.sourceDocumentId,
        sourceDocumentType: draft.sourceDocumentType,
        balanceBeforeQirsh: draft.balanceBeforeQirsh,
        expectedBalanceAfterQirsh: draft.expectedBalanceAfterQirsh,
        reason: draft.reason,
        duration: draft.duration,
      ),
    );
    await _auditLogRepository.record(AuditLogDraft(
      actionType: 'negative_balance.approval.created',
      descriptionAr: 'تم إنشاء موافقة رصيد سالب.',
      referenceId: approval.id,
      metadata: _metadata(approval),
    ));
    return approval.id;
  }

  /// Validates a binding without mutating approval state. The caller must use
  /// [consume] only inside the same rollback boundary that writes the
  /// financial effect.
  Future<void> verify(NegativeBalanceApprovalBinding binding) async {
    binding.validate();
    final approval = await _approvalRepository.findById(binding.approvalId);
    if (approval == null) throw StateError('الموافقة غير موجودة.');
    final owner =
        await _authRepository.getUserById(approval.approvedByOwnerUserId);
    if (owner == null || !owner.canProceed || owner.role != UserRole.owner) {
      throw StateError('مالك الموافقة لم يعد نشطًا أو ليس مالكًا.');
    }
    // The repository repeats this check during the state transition. Keeping
    // both checks avoids treating a UI/service preflight as authorization.
    final current = await _approvalRepository.findById(binding.approvalId);
    if (current == null ||
        current.status != NegativeBalanceApprovalStatus.pending ||
        current.isExpired ||
        current.accountId != binding.accountId ||
        current.amountQirsh != binding.amountQirsh ||
        current.operationType != binding.operationType ||
        current.sourceDocumentId != binding.sourceDocumentId ||
        current.sourceDocumentType != binding.sourceDocumentType ||
        current.requestedByUserId != binding.requestedByUserId ||
        current.balanceBeforeQirsh != binding.balanceBeforeQirsh ||
        current.expectedBalanceAfterQirsh !=
            binding.expectedBalanceAfterQirsh) {
      throw StateError('بيانات الموافقة لا تطابق العملية.');
    }
  }

  Future<NegativeBalanceApprovalConsumption> consume(
    NegativeBalanceApprovalBinding binding,
  ) async {
    await verify(binding);
    final consumed = await _approvalRepository.consumeBoundApproval(binding);
    await _auditLogRepository.record(AuditLogDraft(
      actionType: 'negative_balance.approval.consumed',
      descriptionAr: 'تم استهلاك موافقة رصيد سالب.',
      referenceId: consumed.id,
      metadata: <String, Object?>{
        ..._metadata(consumed),
        'transactionId': binding.transactionId,
        'result': 'consumed',
      },
    ));
    return NegativeBalanceApprovalConsumption._(
      approvalRepository: _approvalRepository,
      approvalId: consumed.id,
      transactionId: binding.transactionId,
      binding: binding,
    );
  }

  Map<String, Object?> _metadata(NegativeBalanceApproval approval) =>
      <String, Object?>{
        'approvalId': approval.id,
        'requesterUserId': approval.requestedByUserId,
        'approvedByOwnerUserId': approval.approvedByOwnerUserId,
        'accountId': approval.accountId,
        'amountQirsh': approval.amountQirsh,
        'balanceBeforeQirsh': approval.balanceBeforeQirsh,
        'balanceAfterQirsh': approval.expectedBalanceAfterQirsh,
        'operationType': approval.operationType.name,
        'sourceDocumentId': approval.sourceDocumentId,
        'sourceDocumentType': approval.sourceDocumentType,
        'reason': approval.reason,
        'timestamp': DateTime.now().toIso8601String(),
      };
}

class NegativeBalanceApprovalConsumption {
  NegativeBalanceApprovalConsumption._({
    required NegativeBalanceApprovalRepository approvalRepository,
    required this.approvalId,
    required this.transactionId,
    required NegativeBalanceApprovalBinding binding,
  })  : _approvalRepository = approvalRepository,
        _binding = binding;

  final NegativeBalanceApprovalRepository _approvalRepository;
  final String approvalId;
  final String transactionId;
  final NegativeBalanceApprovalBinding _binding;
  bool _supplierEntryClaimed = false;

  void claimSupplierOverpaymentEntry({
    required String accountId,
    required int amountQirsh,
    required String createdByUserId,
  }) {
    if (_supplierEntryClaimed ||
        _binding.operationType !=
            NegativeBalanceOperationType.supplierOverpayment ||
        _binding.sourceDocumentType != 'supplierOverpayment' ||
        _binding.accountId != accountId.trim() ||
        _binding.requestedByUserId != createdByUserId.trim() ||
        _binding.balanceBeforeQirsh - _binding.expectedBalanceAfterQirsh !=
            amountQirsh) {
      throw StateError(
          'Supplier overpayment authorization does not match the financial entry.');
    }
    _supplierEntryClaimed = true;
  }

  Future<void> rollback() => _approvalRepository.restorePendingApproval(
        approvalId: approvalId,
        consumedByTransactionId: transactionId,
      );
}
