enum InternalTransferPostingAttemptState {
  queued,
  sending,
  confirmed,
  confirmedProjectionPending,
  rejected,
  unknownOutcome,
}

final class InternalTransferPostingAttempt {
  const InternalTransferPostingAttempt({
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
  final InternalTransferPostingAttemptState state;
  final String? canonicalServerResultJson;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int attemptCount;
  final String? lastErrorCode;
}

final class InternalTransferPostingAttemptConflictException
    implements Exception {
  const InternalTransferPostingAttemptConflictException();
}

abstract interface class InternalTransferPostingAttemptStore {
  Future<InternalTransferPostingAttempt> prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
  });

  Future<InternalTransferPostingAttempt?> load(String commandId);
  Future<List<InternalTransferPostingAttempt>> loadIncompleteForBusiness(
    String businessId,
  );
  Future<void> markSending(String commandId);
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  );
  Future<void> markConfirmed(String commandId);
  Future<void> markFailure(
    String commandId, {
    required InternalTransferPostingAttemptState state,
    required String errorCode,
  });
}
