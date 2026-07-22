import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

enum NegativeBalanceApprovalRequestOperationType {
  supplierPayment,
  expense,
  paidPurchase;

  String get labelAr => switch (this) {
        supplierPayment => 'سداد مورد',
        expense => 'مصروف',
        paidPurchase => 'شراء مدفوع',
      };
}

enum NegativeBalanceApprovalRequestStatus {
  pending,
  executed,
  rejected,
  cancelled,
  stale;

  bool get isTerminal => this != pending;

  String get labelAr => switch (this) {
        pending => 'قيد الانتظار',
        executed => 'مُنفذ',
        rejected => 'مرفوض',
        cancelled => 'ملغي',
        stale => 'قديم وغير صالح',
      };
}

class NegativeBalanceApprovalRequest {
  NegativeBalanceApprovalRequest({
    required this.id,
    required this.idempotencyKey,
    required this.operationType,
    required this.status,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.amountQirsh,
    required this.sourceDocumentId,
    required this.payloadJson,
    required this.payloadFingerprint,
    required this.requesterActorId,
    required this.requestedAt,
    required this.balanceAtRequestQirsh,
    required this.expectedBalanceAtRequestQirsh,
    required this.deficitAtRequestQirsh,
    required this.reason,
    this.relatedPartyId,
    this.resolverActorId,
    this.resolvedAt,
    this.resolutionReason,
    this.ownerVerificationReference,
    this.resultDocumentId,
    this.recordVersion = 1,
  }) {
    if (id.trim().isEmpty ||
        idempotencyKey.trim().isEmpty ||
        financialAccountId.trim().isEmpty ||
        sourceDocumentId.trim().isEmpty ||
        payloadJson.trim().isEmpty ||
        payloadFingerprint.trim().isEmpty ||
        requesterActorId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError(
          'Approval request identifiers and reason are required.');
    }
    if (amountQirsh <= 0 || deficitAtRequestQirsh <= 0 || recordVersion <= 0) {
      throw ArgumentError(
          'Approval request amounts and version must be positive.');
    }
    if (expectedBalanceAtRequestQirsh != balanceAtRequestQirsh - amountQirsh) {
      throw ArgumentError('Approval request balance projection is invalid.');
    }
    if (deficitAtRequestQirsh != -expectedBalanceAtRequestQirsh ||
        expectedBalanceAtRequestQirsh >= 0) {
      throw ArgumentError('Approval request must represent a real deficit.');
    }
    if (status == NegativeBalanceApprovalRequestStatus.pending &&
        (resolverActorId != null ||
            resolvedAt != null ||
            resolutionReason != null ||
            ownerVerificationReference != null ||
            resultDocumentId != null)) {
      throw ArgumentError(
          'Pending request cannot contain resolution metadata.');
    }
    if (status.isTerminal &&
        (resolverActorId?.trim().isEmpty != false || resolvedAt == null)) {
      throw ArgumentError(
          'Terminal request requires resolver identity and time.');
    }
    if (status == NegativeBalanceApprovalRequestStatus.executed &&
        (ownerVerificationReference?.trim().isEmpty != false ||
            resultDocumentId?.trim().isEmpty != false)) {
      throw ArgumentError(
          'Executed request requires verification and result references.');
    }
  }

  final String id;
  final String idempotencyKey;
  final NegativeBalanceApprovalRequestOperationType operationType;
  final NegativeBalanceApprovalRequestStatus status;
  final String financialAccountId;
  final PaymentMethod paymentMethod;
  final int amountQirsh;
  final String sourceDocumentId;
  final String payloadJson;
  final String payloadFingerprint;
  final String? relatedPartyId;
  final String requesterActorId;
  final DateTime requestedAt;
  final int balanceAtRequestQirsh;
  final int expectedBalanceAtRequestQirsh;
  final int deficitAtRequestQirsh;
  final String reason;
  final String? resolverActorId;
  final DateTime? resolvedAt;
  final String? resolutionReason;
  final String? ownerVerificationReference;
  final String? resultDocumentId;
  final int recordVersion;

  String get pendingSignature => [
        operationType.name,
        sourceDocumentId,
        financialAccountId,
        paymentMethod.name,
        amountQirsh,
        payloadFingerprint,
      ].join('|');

  NegativeBalanceApprovalRequest resolve({
    required NegativeBalanceApprovalRequestStatus status,
    required String resolverActorId,
    required DateTime resolvedAt,
    required String resolutionReason,
    String? ownerVerificationReference,
    String? resultDocumentId,
  }) {
    if (this.status != NegativeBalanceApprovalRequestStatus.pending ||
        !status.isTerminal) {
      throw StateError('Only a pending approval request can be resolved.');
    }
    return NegativeBalanceApprovalRequest(
      id: id,
      idempotencyKey: idempotencyKey,
      operationType: operationType,
      status: status,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
      amountQirsh: amountQirsh,
      sourceDocumentId: sourceDocumentId,
      payloadJson: payloadJson,
      payloadFingerprint: payloadFingerprint,
      relatedPartyId: relatedPartyId,
      requesterActorId: requesterActorId,
      requestedAt: requestedAt,
      balanceAtRequestQirsh: balanceAtRequestQirsh,
      expectedBalanceAtRequestQirsh: expectedBalanceAtRequestQirsh,
      deficitAtRequestQirsh: deficitAtRequestQirsh,
      reason: reason,
      resolverActorId: resolverActorId.trim(),
      resolvedAt: resolvedAt,
      resolutionReason: resolutionReason.trim(),
      ownerVerificationReference: ownerVerificationReference?.trim(),
      resultDocumentId: resultDocumentId?.trim(),
      recordVersion: recordVersion,
    );
  }
}

class NegativeBalanceApprovalRequestDraft {
  const NegativeBalanceApprovalRequestDraft({
    required this.idempotencyKey,
    required this.operationType,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.amountQirsh,
    required this.sourceDocumentId,
    required this.payloadJson,
    required this.payloadFingerprint,
    required this.requesterActorId,
    required this.balanceAtRequestQirsh,
    required this.expectedBalanceAtRequestQirsh,
    required this.deficitAtRequestQirsh,
    required this.reason,
    this.relatedPartyId,
  });

  final String idempotencyKey;
  final NegativeBalanceApprovalRequestOperationType operationType;
  final String financialAccountId;
  final PaymentMethod paymentMethod;
  final int amountQirsh;
  final String sourceDocumentId;
  final String payloadJson;
  final String payloadFingerprint;
  final String? relatedPartyId;
  final String requesterActorId;
  final int balanceAtRequestQirsh;
  final int expectedBalanceAtRequestQirsh;
  final int deficitAtRequestQirsh;
  final String reason;
}

class NegativeBalanceApprovalRequestTransition {
  NegativeBalanceApprovalRequestTransition({
    required this.id,
    required this.requestId,
    required this.toStatus,
    required this.actorId,
    required this.occurredAt,
    required this.reason,
    this.fromStatus,
  }) {
    if (id.trim().isEmpty ||
        requestId.trim().isEmpty ||
        actorId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError(
          'Approval transition identifiers and reason are required.');
    }
  }

  final String id;
  final String requestId;
  final NegativeBalanceApprovalRequestStatus? fromStatus;
  final NegativeBalanceApprovalRequestStatus toStatus;
  final String actorId;
  final DateTime occurredAt;
  final String reason;
}
