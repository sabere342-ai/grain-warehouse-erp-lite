export 'audit_log_entry.dart';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_entry.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class AuditLogRepository {
  Future<AuditLogEntry> record(AuditLogDraft draft);

  Future<bool> hasRecordedAction({
    required String actionType,
    required String referenceId,
  });
}

abstract interface class AuditLogStorageRepository {
  Future<List<AuditLogEntry>> exportStoredAuditLogs();
  Future<void> restoreAuditLogsIntoEmpty(List<AuditLogEntry> entries);
  Future<void> clearForOwnerDataWipe();
}

abstract class DurableAuditLogRepository
    implements
        AuditLogRepository,
        AuditLogReadRepository,
        AuditLogStorageRepository,
        TransactionSnapshotProvider {}

class LocalAuditLogRepository implements DurableAuditLogRepository {
  final List<AuditLogEntry> _entries = [];
  int _generatedIdCounter = 0;

  @override
  Future<List<AuditLogReadModel>> listAuditLogs() async {
    return _sortedEntries()
        .map(
          (log) => AuditLogReadModel(
            id: log.id,
            timestamp: log.timestamp,
            descriptionAr: log.descriptionAr,
            referenceId: log.referenceId,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AuditLogEntry>> exportStoredAuditLogs() async =>
      List<AuditLogEntry>.unmodifiable(_sortedEntries());

  @override
  Future<bool> hasRecordedAction({
    required String actionType,
    required String referenceId,
  }) async =>
      _entries.any(
        (entry) =>
            entry.actionType == actionType && entry.referenceId == referenceId,
      );

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) async {
    _validateDraft(draft);
    final timestamp = draft.timestamp ?? DateTime.now();
    final entry = AuditLogEntry(
      id: _generateAuditId(timestamp),
      timestamp: timestamp,
      actionType: draft.actionType.trim(),
      descriptionAr: draft.descriptionAr.trim(),
      actorId: _normalizedOptionalText(draft.actorId),
      referenceId: _normalizedOptionalText(draft.referenceId),
      metadata: Map<String, Object?>.unmodifiable(draft.metadata),
    );
    _entries.add(entry);
    return entry;
  }

  @override
  Future<void> restoreAuditLogsIntoEmpty(List<AuditLogEntry> entries) async {
    if (_entries.isNotEmpty) {
      throw StateError('Audit repository is not empty.');
    }
    _validateUniqueRestoredEntries(entries);
    _entries.addAll(entries);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _entries.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      ObjectStateSnapshot<(List<AuditLogEntry>, int)>(
        captureState: () =>
            (List<AuditLogEntry>.from(_entries), _generatedIdCounter),
        restoreState: (state) {
          _entries
            ..clear()
            ..addAll(state.$1);
          _generatedIdCounter = state.$2;
        },
      );

  void _validateDraft(AuditLogDraft draft) {
    if (draft.actionType.trim().isEmpty || draft.descriptionAr.trim().isEmpty) {
      throw ArgumentError('Audit action type and description are required.');
    }
  }

  void _validateUniqueRestoredEntries(List<AuditLogEntry> entries) {
    final ids = <String>{};
    for (final entry in entries) {
      if (!entry.hasValidId ||
          entry.actionType.trim().isEmpty ||
          entry.descriptionAr.trim().isEmpty) {
        throw StateError('Invalid audit backup record.');
      }
      if (!ids.add(entry.id)) {
        throw StateError('Duplicate audit id.');
      }
    }
  }

  String _generateAuditId(DateTime timestamp) {
    _generatedIdCounter++;
    return 'aud-${timestamp.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  List<AuditLogEntry> _sortedEntries() =>
      [..._entries]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}
