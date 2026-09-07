final class ConfirmedInternalTransferProjection {
  const ConfirmedInternalTransferProjection({
    required this.commandId,
    required this.localFingerprint,
    required this.businessId,
    required this.sourceServerAccountId,
    required this.destinationServerAccountId,
    required this.transferId,
    required this.displayNumber,
    required this.transferReference,
    required this.sourceEntryId,
    required this.destinationEntryId,
    required this.auditEventIds,
    required this.serverAcceptedAtUtc,
    required this.effectiveBusinessDate,
    required this.amountQirsh,
    required this.note,
    required this.actorAuthUserId,
    required this.sourceBalanceAfterQirsh,
    required this.destinationBalanceAfterQirsh,
  });

  final String commandId;
  final String localFingerprint;
  final String businessId;
  final String sourceServerAccountId;
  final String destinationServerAccountId;
  final String transferId;
  final String displayNumber;
  final String transferReference;
  final String sourceEntryId;
  final String destinationEntryId;
  final List<String> auditEventIds;
  final DateTime serverAcceptedAtUtc;
  final String effectiveBusinessDate;
  final int amountQirsh;
  final String? note;
  final String actorAuthUserId;
  final int sourceBalanceAfterQirsh;
  final int destinationBalanceAfterQirsh;
}

abstract interface class ConfirmedInternalTransferProjectionWriter {
  Future<void> project(ConfirmedInternalTransferProjection value);
}
