import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';

enum DurableConflictClassification {
  versionMismatch,
  payloadMismatchAtSameVersion,
  deleteVsUpdate,
  duplicateNaturalKey,
  acknowledgedProjectionMismatch,
  reconciliationMismatch,
}

enum DurableConflictResolutionState { unresolved, resolved }

final class DurableConflictEvidence {
  DurableConflictEvidence({
    required this.conflictId,
    required this.scope,
    required String entityType,
    required String entityId,
    this.localEntityVersion,
    this.remoteEntityVersion,
    required this.localPayloadJson,
    required this.remotePayloadJson,
    this.localOperationId,
    this.remoteOperationId,
    this.remoteSourceAuthority,
    this.localDeletionMetadata,
    this.remoteDeletionMetadata,
    required this.classification,
    required DateTime detectedAtUtc,
  })  : entityType = entityType.trim(),
        entityId = entityId.trim(),
        localPayloadFingerprint = _fingerprintSnapshot(localPayloadJson),
        remotePayloadFingerprint = _fingerprintSnapshot(remotePayloadJson),
        detectedAtUtc = requireUtcInstant(detectedAtUtc, 'detectedAtUtc') {
    if (this.entityType.isEmpty || this.entityId.isEmpty) {
      throw ArgumentError('Conflict entity identity is required.');
    }
  }

  final String conflictId;
  final DurableScope scope;
  final String entityType;
  final String entityId;
  final EntityVersion? localEntityVersion;
  final EntityVersion? remoteEntityVersion;
  final String localPayloadJson;
  final String remotePayloadJson;
  final String localPayloadFingerprint;
  final String remotePayloadFingerprint;
  final OperationId? localOperationId;
  final OperationId? remoteOperationId;
  final String? remoteSourceAuthority;
  final DeletionMetadata? localDeletionMetadata;
  final DeletionMetadata? remoteDeletionMetadata;
  final DurableConflictClassification classification;
  final DateTime detectedAtUtc;

  bool get localDeleted => localDeletionMetadata != null;
  bool get remoteDeleted => remoteDeletionMetadata != null;

  String get conflictKey {
    final value = canonicalJson(<String, Object?>{
      'businessId': scope.businessId.value,
      'scopeKind': scope.kind.name,
      'warehouseId': scope.warehouseId?.value,
      'entityType': entityType,
      'entityId': entityId,
      'localEntityVersion': localEntityVersion?.value,
      'remoteEntityVersion': remoteEntityVersion?.value,
      'localPayloadFingerprint': localPayloadFingerprint,
      'remotePayloadFingerprint': remotePayloadFingerprint,
      'localOperationId': localOperationId?.value,
      'remoteOperationId': remoteOperationId?.value,
      'remoteSourceAuthority': remoteSourceAuthority,
      'localDeleted': localDeleted,
      'remoteDeleted': remoteDeleted,
      'classification': classification.name,
    });
    return sha256.convert(utf8.encode(value)).toString();
  }
}

String _fingerprintSnapshot(String payload) {
  try {
    jsonDecode(payload);
  } on Object {
    throw ArgumentError.value(payload, 'payload', 'Canonical JSON required.');
  }
  return sha256.convert(utf8.encode(payload)).toString();
}

final class DurableConflict {
  const DurableConflict({
    required this.evidence,
    required this.resolutionState,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.recordVersion,
  });

  final DurableConflictEvidence evidence;
  final DurableConflictResolutionState resolutionState;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int recordVersion;
}

final class DurableProjectionConflictException implements Exception {
  const DurableProjectionConflictException(this.evidence);
  final DurableConflictEvidence evidence;
}
