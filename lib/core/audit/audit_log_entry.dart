class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.actionType,
    required this.descriptionAr,
    this.referenceId,
  });

  final String id;
  final DateTime timestamp;
  final String actionType;
  final String descriptionAr;
  final String? referenceId;

  bool get hasValidId => id.trim().isNotEmpty;
}

class AuditLogDraft {
  const AuditLogDraft({
    required this.actionType,
    required this.descriptionAr,
    this.referenceId,
    this.timestamp,
  });

  final String actionType;
  final String descriptionAr;
  final String? referenceId;
  final DateTime? timestamp;
}
