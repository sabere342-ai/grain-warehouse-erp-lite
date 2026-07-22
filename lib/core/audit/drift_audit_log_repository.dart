import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftAuditLogRepository implements DurableAuditLogRepository {
  DriftAuditLogRepository(this._database);

  final db.FoundationDatabase _database;
  static const _sequenceKey = 'audit_logs';

  @override
  Future<List<AuditLogEntry>> listLogs() async {
    final query = _database.select(_database.auditLogs)
      ..orderBy([
        (row) => OrderingTerm.desc(row.timestamp),
        (row) => OrderingTerm.desc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      final sequence = await _takeSequence();
      final timestamp = draft.timestamp ?? DateTime.now();
      final entry = AuditLogEntry(
        id: 'aud-${timestamp.microsecondsSinceEpoch}-$sequence',
        timestamp: timestamp,
        actionType: draft.actionType.trim(),
        descriptionAr: draft.descriptionAr.trim(),
        actorId: _optional(draft.actorId),
        referenceId: _optional(draft.referenceId),
        metadata: Map<String, Object?>.unmodifiable(draft.metadata),
      );
      await _database.into(_database.auditLogs).insert(_companion(entry));
      return entry;
    });
  }

  @override
  Future<void> restoreAuditLogsIntoEmpty(List<AuditLogEntry> entries) =>
      _database.transaction(() async {
        if (await _database.auditLogs.count().getSingle() != 0) {
          throw StateError('Audit repository is not empty.');
        }
        _validateRestored(entries);
        for (final entry in entries) {
          await _database.into(_database.auditLogs).insert(_companion(entry));
        }
        var maximum = 0;
        for (final entry in entries) {
          final value = int.tryParse(entry.id.split('-').last) ?? 0;
          if (value > maximum) maximum = value;
        }
        await _database
            .into(_database.repositorySequences)
            .insertOnConflictUpdate(db.RepositorySequencesCompanion.insert(
              repository: _sequenceKey,
              nextValue: maximum + 1,
            ));
      });

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.auditLogs).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftAuditSnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((value) => value.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.into(_database.repositorySequences).insertOnConflictUpdate(
          db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey,
            nextValue: value + 1,
          ),
        );
    return value;
  }

  db.AuditLogsCompanion _companion(AuditLogEntry entry) =>
      db.AuditLogsCompanion.insert(
        id: entry.id,
        timestamp: entry.timestamp,
        actionType: entry.actionType,
        descriptionAr: entry.descriptionAr,
        actorId: Value(entry.actorId),
        referenceId: Value(entry.referenceId),
        metadataJson: jsonEncode(_canonicalJsonMap(entry.metadata)),
      );

  AuditLogEntry _toDomain(db.AuditLogRow row) => AuditLogEntry(
        id: row.id,
        timestamp: row.timestamp,
        actionType: row.actionType,
        descriptionAr: row.descriptionAr,
        actorId: row.actorId,
        referenceId: row.referenceId,
        metadata: Map<String, Object?>.unmodifiable(
          _decodeMetadata(row.metadataJson),
        ),
      );

  Map<String, Object?> _decodeMetadata(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Audit metadata must be a JSON object.');
    }
    return value.cast<String, Object?>();
  }

  Map<String, Object?> _canonicalJsonMap(Map<String, Object?> source) {
    final keys = source.keys.toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJsonValue(source[key]),
    };
  }

  Object? _canonicalJsonValue(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is List<Object?>) {
      return value.map(_canonicalJsonValue).toList(growable: false);
    }
    if (value is Map<String, Object?>) return _canonicalJsonMap(value);
    throw ArgumentError.value(value, 'metadata', 'Value is not JSON-safe.');
  }

  void _validateDraft(AuditLogDraft draft) {
    if (draft.actionType.trim().isEmpty || draft.descriptionAr.trim().isEmpty) {
      throw ArgumentError('Audit action type and description are required.');
    }
    _canonicalJsonMap(draft.metadata);
  }

  void _validateRestored(List<AuditLogEntry> entries) {
    final ids = <String>{};
    for (final entry in entries) {
      if (!entry.hasValidId ||
          entry.actionType.trim().isEmpty ||
          entry.descriptionAr.trim().isEmpty) {
        throw StateError('Invalid audit backup record.');
      }
      if (!ids.add(entry.id)) throw StateError('Duplicate audit id.');
      _canonicalJsonMap(entry.metadata);
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _DriftAuditSnapshot extends SnapshotHolder {
  _DriftAuditSnapshot(this.repository);

  final DriftAuditLogRepository repository;
  List<AuditLogEntry>? _entries;

  @override
  Future<void> capture() async => _entries = await repository.listLogs();

  @override
  Future<void> rollback() async {
    final entries = _entries;
    if (entries == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreAuditLogsIntoEmpty(entries);
  }
}
