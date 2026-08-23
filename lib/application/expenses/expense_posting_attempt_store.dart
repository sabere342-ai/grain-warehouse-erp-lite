enum ExpensePostingAttemptState {
  draft,
  queued,
  sending,
  confirmed,
  confirmedProjectionPending,
  rejected,
  unknownOutcome,
}

final class ExpensePostingAttempt {
  const ExpensePostingAttempt({
    required this.commandId,
    required this.businessId,
    required this.canonicalPayloadJson,
    required this.localFingerprint,
    required this.state,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.canonicalServerResultJson,
    this.attemptCount = 0,
    this.lastErrorCode,
  });

  final String commandId;
  final String businessId;
  final String canonicalPayloadJson;
  final String localFingerprint;
  final ExpensePostingAttemptState state;
  final String? canonicalServerResultJson;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int attemptCount;
  final String? lastErrorCode;

  ExpensePostingAttempt copyWith({
    ExpensePostingAttemptState? state,
    String? canonicalServerResultJson,
    DateTime? updatedAtUtc,
    int? attemptCount,
    String? lastErrorCode,
  }) =>
      ExpensePostingAttempt(
        commandId: commandId,
        businessId: businessId,
        canonicalPayloadJson: canonicalPayloadJson,
        localFingerprint: localFingerprint,
        state: state ?? this.state,
        canonicalServerResultJson:
            canonicalServerResultJson ?? this.canonicalServerResultJson,
        createdAtUtc: createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
        attemptCount: attemptCount ?? this.attemptCount,
        lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      );
}

final class ExpensePostingAttemptConflictException implements Exception {
  const ExpensePostingAttemptConflictException();
}

final class FinancialAccountCloudLink {
  const FinancialAccountCloudLink({
    required this.localAccountId,
    required this.businessId,
    required this.serverAccountUuid,
    required this.reconciledServerBalanceQirsh,
    required this.reconciledAtUtc,
    required this.reconciliationVersion,
    required this.readyAtUtc,
  });

  final String localAccountId;
  final String businessId;
  final String serverAccountUuid;
  final int reconciledServerBalanceQirsh;
  final DateTime reconciledAtUtc;
  final int reconciliationVersion;
  final DateTime readyAtUtc;
}

abstract interface class FinancialAccountCloudLinkResolver {
  Future<FinancialAccountCloudLink?> readyLinkForLocalAccount({
    required String localAccountId,
    required String businessId,
  });
}

abstract interface class ExpensePostingAttemptStore {
  Future<ExpensePostingAttempt> prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
  });

  Future<ExpensePostingAttempt?> load(String commandId);
  Future<void> markSending(String commandId);
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  );
  Future<void> markConfirmed(String commandId);
  Future<void> markFailure(
    String commandId, {
    required ExpensePostingAttemptState state,
    required String errorCode,
  });
}
