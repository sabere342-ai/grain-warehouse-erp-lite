class CancellationMetadata {
  const CancellationMetadata({
    required this.cancelledAt,
    required this.cancelledByUserId,
    required this.cancellationReason,
    required this.originalDocumentId,
    required this.reversalMovementIds,
  });

  final DateTime cancelledAt;
  final String cancelledByUserId;
  final String cancellationReason;
  final String originalDocumentId;
  final List<String> reversalMovementIds;
}
