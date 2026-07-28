final class AuditLogReadModel {
  const AuditLogReadModel({
    required this.id,
    required this.timestamp,
    required this.descriptionAr,
    this.referenceId,
  });

  final String id;
  final DateTime timestamp;
  final String descriptionAr;
  final String? referenceId;
}

abstract interface class AuditLogReadRepository {
  /// Returns all audit logs ordered by timestamp descending, then id
  /// descending. The future may complete with an implementation error.
  Future<List<AuditLogReadModel>> listAuditLogs();
}
