enum PostExpenseFailureCategory {
  validation,
  authentication,
  authorization,
  businessContext,
  account,
  paymentRoute,
  period,
  balance,
  approval,
  idempotency,
  connectivity,
  transaction,
  projection,
  unexpected,
}

final class ExpensePostingRequestPayload {
  const ExpensePostingRequestPayload({
    required this.commandId,
    required this.schemaVersion,
    required this.businessId,
    required this.businessDate,
    required this.category,
    required this.amountQirsh,
    required this.notes,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.accountingClassification,
  });

  final String commandId;
  final int schemaVersion;
  final String businessId;
  final String businessDate;
  final String category;
  final int amountQirsh;
  final String? notes;
  final String financialAccountId;
  final String paymentMethod;
  final String accountingClassification;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
        'accountingClassification': accountingClassification,
        'amountQirsh': amountQirsh,
        'businessDate': businessDate,
        'businessId': businessId,
        'category': category,
        'commandId': commandId,
        'financialAccountId': financialAccountId,
        'notes': notes,
        'paymentMethod': paymentMethod,
        'schemaVersion': schemaVersion,
      };

  Map<String, Object?> toRpcParameters() => <String, Object?>{
        'p_command_id': commandId,
        'p_schema_version': schemaVersion,
        'p_business_id': businessId,
        'p_business_date': businessDate,
        'p_category': category,
        'p_amount_qirsh': amountQirsh,
        'p_notes': notes,
        'p_financial_account_id': financialAccountId,
        'p_payment_method': paymentMethod,
        'p_accounting_classification': accountingClassification,
      };
}

sealed class ExpensePostingGatewayResponse {
  const ExpensePostingGatewayResponse();
}

final class ExpensePostingGatewaySuccess extends ExpensePostingGatewayResponse {
  const ExpensePostingGatewaySuccess({
    required this.commandId,
    required this.businessId,
    required this.expenseId,
    required this.financialEntryId,
    required this.auditEventIds,
    required this.serverAcceptedAtUtc,
    required this.businessDate,
    required this.amountQirsh,
    required this.balanceAfterQirsh,
    required this.replayed,
  });

  final String commandId;
  final String businessId;
  final String expenseId;
  final String financialEntryId;
  final List<String> auditEventIds;
  final DateTime serverAcceptedAtUtc;
  final String businessDate;
  final int amountQirsh;
  final int balanceAfterQirsh;
  final bool replayed;
}

final class ExpensePostingGatewayFailure extends ExpensePostingGatewayResponse {
  const ExpensePostingGatewayFailure({
    required this.category,
    required this.code,
    required this.retryable,
    this.fieldErrors = const <String, String>{},
    this.diagnosticReference,
  });

  final PostExpenseFailureCategory category;
  final String code;
  final bool retryable;
  final Map<String, String> fieldErrors;
  final String? diagnosticReference;
}

abstract interface class ExpensePostingGateway {
  Future<ExpensePostingGatewayResponse> post(
    ExpensePostingRequestPayload payload,
  );
}
