class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.actionType,
    required this.descriptionAr,
    this.actorId,
    this.referenceId,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final DateTime timestamp;
  final String actionType;
  final String descriptionAr;
  final String? actorId;
  final String? referenceId;
  final Map<String, Object?> metadata;

  bool get hasValidId => id.trim().isNotEmpty;
}

class AuditLogDraft {
  const AuditLogDraft({
    required this.actionType,
    required this.descriptionAr,
    this.actorId,
    this.referenceId,
    this.timestamp,
    this.metadata = const <String, Object?>{},
  });

  final String actionType;
  final String descriptionAr;
  final String? actorId;
  final String? referenceId;
  final DateTime? timestamp;
  final Map<String, Object?> metadata;
}
