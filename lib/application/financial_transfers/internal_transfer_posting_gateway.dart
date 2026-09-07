enum PostInternalTransferFailureCategory {
  validation,
  authentication,
  authorization,
  businessContext,
  account,
  period,
  balance,
  idempotency,
  connectivity,
  transaction,
  projection,
  unexpected,
}

final class InternalTransferPostingRequestPayload {
  const InternalTransferPostingRequestPayload({
    required this.commandId,
    required this.schemaVersion,
    required this.businessId,
    required this.sourceFinancialAccountId,
    required this.destinationFinancialAccountId,
    required this.amountQirsh,
    required this.effectiveBusinessDate,
    required this.transferReference,
    required this.note,
  });

  final String commandId;
  final int schemaVersion;
  final String businessId;
  final String sourceFinancialAccountId;
  final String destinationFinancialAccountId;
  final int amountQirsh;
  final String effectiveBusinessDate;
  final String transferReference;
  final String? note;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
        'amountQirsh': amountQirsh,
        'businessId': businessId,
        'commandId': commandId,
        'destinationFinancialAccountId': destinationFinancialAccountId,
        'effectiveBusinessDate': effectiveBusinessDate,
        'note': note,
        'schemaVersion': schemaVersion,
        'sourceFinancialAccountId': sourceFinancialAccountId,
        'transferReference': transferReference,
      };

  Map<String, Object?> toRpcParameters() => <String, Object?>{
        'p_command_id': commandId,
        'p_schema_version': schemaVersion,
        'p_business_id': businessId,
        'p_source_financial_account_id': sourceFinancialAccountId,
        'p_destination_financial_account_id': destinationFinancialAccountId,
        'p_amount_qirsh': amountQirsh,
        'p_effective_business_date': effectiveBusinessDate,
        'p_transfer_reference': transferReference,
        'p_note': note,
      };
}

sealed class InternalTransferPostingGatewayResponse {
  const InternalTransferPostingGatewayResponse();
}

final class InternalTransferPostingGatewaySuccess
    extends InternalTransferPostingGatewayResponse {
  const InternalTransferPostingGatewaySuccess({
    required this.commandId,
    required this.businessId,
    required this.transferId,
    required this.displayNumber,
    required this.transferReference,
    required this.sourceFinancialAccountId,
    required this.destinationFinancialAccountId,
    required this.sourceFinancialEntryId,
    required this.destinationFinancialEntryId,
    required this.auditEventIds,
    required this.effectiveBusinessDate,
    required this.amountQirsh,
    required this.sourceBalanceAfterQirsh,
    required this.destinationBalanceAfterQirsh,
    required this.serverAcceptedAtUtc,
    required this.replayed,
  });

  final String commandId;
  final String businessId;
  final String transferId;
  final String displayNumber;
  final String transferReference;
  final String sourceFinancialAccountId;
  final String destinationFinancialAccountId;
  final String sourceFinancialEntryId;
  final String destinationFinancialEntryId;
  final List<String> auditEventIds;
  final String effectiveBusinessDate;
  final int amountQirsh;
  final int sourceBalanceAfterQirsh;
  final int destinationBalanceAfterQirsh;
  final DateTime serverAcceptedAtUtc;
  final bool replayed;
}

final class InternalTransferPostingGatewayFailure
    extends InternalTransferPostingGatewayResponse {
  const InternalTransferPostingGatewayFailure({
    required this.category,
    required this.code,
    required this.retryable,
    this.fieldErrors = const <String, String>{},
    this.diagnosticReference,
  });

  final PostInternalTransferFailureCategory category;
  final String code;
  final bool retryable;
  final Map<String, String> fieldErrors;
  final String? diagnosticReference;
}

abstract interface class InternalTransferPostingGateway {
  Future<InternalTransferPostingGatewayResponse> post(
    InternalTransferPostingRequestPayload payload,
  );
}
