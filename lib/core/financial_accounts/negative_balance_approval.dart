enum NegativeBalanceApprovalStatus {
  pending,
  consumed,
  expired,
  revoked;

  String get labelAr {
    switch (this) {
      case NegativeBalanceApprovalStatus.pending:
        return 'قيد الانتظار';
      case NegativeBalanceApprovalStatus.consumed:
        return 'مستخدم';
      case NegativeBalanceApprovalStatus.expired:
        return 'منتهي الصلاحية';
      case NegativeBalanceApprovalStatus.revoked:
        return 'ملغى';
    }
  }
}

enum NegativeBalanceOperationType {
  expense,
  supplierPayment,
  purchasePayment,
  transfer,
  cancellationReversal,
  customerOverpayment,
  supplierOverpayment,
  supplierAdvanceRefundReversal,
  customerAdvanceRefund;

  String get labelAr {
    switch (this) {
      case NegativeBalanceOperationType.expense:
        return 'مصروف';
      case NegativeBalanceOperationType.supplierPayment:
        return 'دفع مورد';
      case NegativeBalanceOperationType.purchasePayment:
        return 'دفع مشتريات';
      case NegativeBalanceOperationType.transfer:
        return 'تحويل مالي';
      case NegativeBalanceOperationType.cancellationReversal:
        return 'عكس إلغاء';
      case NegativeBalanceOperationType.customerOverpayment:
        return '\u0632\u064a\u0627\u062f\u0629 \u0639\u0645\u064a\u0644';
      case NegativeBalanceOperationType.supplierOverpayment:
        return '\u0632\u064a\u0627\u062f\u0629 \u0645\u0648\u0631\u062f';
      case NegativeBalanceOperationType.supplierAdvanceRefundReversal:
        return '\u0639\u0643\u0633 \u0627\u0633\u062a\u0631\u062f\u0627\u062f \u0633\u0644\u0641\u0629 \u0627\u0644\u0645\u0648\u0631\u062f';
      case NegativeBalanceOperationType.customerAdvanceRefund:
        return '\u0631\u062f \u0633\u0644\u0641\u0629 \u0639\u0645\u064a\u0644';
    }
  }
}

enum NegativeBalanceFinancialDirection { inflow, outflow }

class NegativeBalanceApprovalContext {
  const NegativeBalanceApprovalContext({
    this.customerId,
    this.supplierId,
    required this.advanceId,
    this.refundId,
    required this.financialDirection,
  });

  const NegativeBalanceApprovalContext.customerAdvanceRefund({
    required this.customerId,
    required this.advanceId,
  })  : supplierId = null,
        refundId = null,
        financialDirection = NegativeBalanceFinancialDirection.outflow;

  const NegativeBalanceApprovalContext.supplierAdvanceRefundReversal({
    required this.supplierId,
    required this.advanceId,
    required this.refundId,
  })  : customerId = null,
        financialDirection = NegativeBalanceFinancialDirection.outflow;

  final String? customerId;
  final String? supplierId;
  final String advanceId;
  final String? refundId;
  final NegativeBalanceFinancialDirection financialDirection;

  bool matches(NegativeBalanceApprovalContext? other) =>
      other != null &&
      customerId == other.customerId &&
      supplierId == other.supplierId &&
      advanceId == other.advanceId &&
      refundId == other.refundId &&
      financialDirection == other.financialDirection;
}

extension NegativeBalanceOperationTypePolicy on NegativeBalanceOperationType {
  bool get requiresNegativeBalance => switch (this) {
        NegativeBalanceOperationType.customerOverpayment ||
        NegativeBalanceOperationType.supplierOverpayment =>
          false,
        _ => true,
      };
}

class NegativeBalanceApproval {
  NegativeBalanceApproval({
    required this.id,
    required this.requestedByUserId,
    required this.approvedByOwnerUserId,
    required this.accountId,
    required this.amountQirsh,
    required this.operationType,
    required this.sourceDocumentId,
    required this.sourceDocumentType,
    required this.balanceBeforeQirsh,
    required this.expectedBalanceAfterQirsh,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.reason,
    this.authorizationContext,
    this.consumedAt,
    this.consumedByTransactionId,
    this.revokedAt,
    this.revokedByUserId,
  }) {
    if (id.trim().isEmpty ||
        requestedByUserId.trim().isEmpty ||
        approvedByOwnerUserId.trim().isEmpty ||
        accountId.trim().isEmpty ||
        sourceDocumentId.trim().isEmpty ||
        sourceDocumentType.trim().isEmpty) {
      throw ArgumentError('Approval identifiers are required.');
    }
    if (amountQirsh <= 0 || reason.trim().isEmpty) {
      throw ArgumentError('Positive amount and reason are required.');
    }
    if (operationType == NegativeBalanceOperationType.customerAdvanceRefund &&
        (authorizationContext == null ||
            authorizationContext!.customerId?.trim().isEmpty != false ||
            authorizationContext!.advanceId.trim().isEmpty ||
            authorizationContext!.financialDirection !=
                NegativeBalanceFinancialDirection.outflow)) {
      throw ArgumentError('بيانات ربط موافقة رد سلفة العميل مطلوبة.');
    }
    if (operationType ==
            NegativeBalanceOperationType.supplierAdvanceRefundReversal &&
        !_isValidSupplierRefundReversalContext(authorizationContext)) {
      throw ArgumentError(
          'Supplier refund reversal approval binding is required.');
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError('Approval expiry must be after creation.');
    }
    if (status == NegativeBalanceApprovalStatus.consumed &&
        (consumedAt == null ||
            consumedByTransactionId?.trim().isEmpty != false)) {
      throw ArgumentError(
          'Consumed approval requires time and transaction id.');
    }
    if (status == NegativeBalanceApprovalStatus.pending &&
        (consumedAt != null ||
            consumedByTransactionId != null ||
            revokedAt != null ||
            revokedByUserId != null)) {
      throw ArgumentError(
          'Pending approval cannot contain lifecycle metadata.');
    }
    if (status == NegativeBalanceApprovalStatus.revoked &&
        (revokedAt == null || revokedByUserId?.trim().isEmpty != false)) {
      throw ArgumentError('Revoked approval requires time and user id.');
    }
    if (status == NegativeBalanceApprovalStatus.expired &&
        (consumedAt != null || consumedByTransactionId != null)) {
      throw ArgumentError('Expired approval cannot contain consumption data.');
    }
  }

  final String id;
  final String requestedByUserId;
  final String approvedByOwnerUserId;
  final String accountId;
  final int amountQirsh;
  final NegativeBalanceOperationType operationType;
  final String sourceDocumentId;
  final String sourceDocumentType;
  final int balanceBeforeQirsh;
  final int expectedBalanceAfterQirsh;
  final DateTime createdAt;
  final DateTime expiresAt;
  final NegativeBalanceApprovalStatus status;
  final String reason;
  final NegativeBalanceApprovalContext? authorizationContext;
  final DateTime? consumedAt;
  final String? consumedByTransactionId;
  final DateTime? revokedAt;
  final String? revokedByUserId;

  bool get hasValidId => id.trim().isNotEmpty;

  bool get isActive =>
      status == NegativeBalanceApprovalStatus.pending &&
      !DateTime.now().isAfter(expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  NegativeBalanceApproval copyWith({
    String? id,
    String? requestedByUserId,
    String? approvedByOwnerUserId,
    String? accountId,
    int? amountQirsh,
    NegativeBalanceOperationType? operationType,
    String? sourceDocumentId,
    String? sourceDocumentType,
    int? balanceBeforeQirsh,
    int? expectedBalanceAfterQirsh,
    DateTime? createdAt,
    DateTime? expiresAt,
    NegativeBalanceApprovalStatus? status,
    String? reason,
    NegativeBalanceApprovalContext? authorizationContext,
    DateTime? consumedAt,
    String? consumedByTransactionId,
    DateTime? revokedAt,
    String? revokedByUserId,
  }) {
    return NegativeBalanceApproval(
      id: id ?? this.id,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      approvedByOwnerUserId:
          approvedByOwnerUserId ?? this.approvedByOwnerUserId,
      accountId: accountId ?? this.accountId,
      amountQirsh: amountQirsh ?? this.amountQirsh,
      operationType: operationType ?? this.operationType,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      sourceDocumentType: sourceDocumentType ?? this.sourceDocumentType,
      balanceBeforeQirsh: balanceBeforeQirsh ?? this.balanceBeforeQirsh,
      expectedBalanceAfterQirsh:
          expectedBalanceAfterQirsh ?? this.expectedBalanceAfterQirsh,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      authorizationContext: authorizationContext ?? this.authorizationContext,
      consumedAt: consumedAt ?? this.consumedAt,
      consumedByTransactionId:
          consumedByTransactionId ?? this.consumedByTransactionId,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedByUserId: revokedByUserId ?? this.revokedByUserId,
    );
  }
}

bool _isValidSupplierRefundReversalContext(
  NegativeBalanceApprovalContext? context,
) =>
    context != null &&
    context.supplierId?.trim().isNotEmpty == true &&
    context.advanceId.trim().isNotEmpty &&
    context.refundId?.trim().isNotEmpty == true &&
    context.financialDirection == NegativeBalanceFinancialDirection.outflow;

class NegativeBalanceApprovalDraft {
  const NegativeBalanceApprovalDraft({
    required this.requestedByUserId,
    required this.approvedByOwnerUserId,
    required this.accountId,
    required this.amountQirsh,
    required this.operationType,
    required this.sourceDocumentId,
    required this.sourceDocumentType,
    required this.balanceBeforeQirsh,
    required this.expectedBalanceAfterQirsh,
    required this.reason,
    this.duration = const Duration(hours: 24),
    this.authorizationContext,
  });

  final String requestedByUserId;
  final String approvedByOwnerUserId;
  final String accountId;
  final int amountQirsh;
  final NegativeBalanceOperationType operationType;
  final String sourceDocumentId;
  final String sourceDocumentType;
  final int balanceBeforeQirsh;
  final int expectedBalanceAfterQirsh;
  final String reason;
  final Duration duration;
  final NegativeBalanceApprovalContext? authorizationContext;
}
