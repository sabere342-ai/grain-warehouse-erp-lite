import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';

enum DurableScopeKind { businessWide, warehouse }

final class DurableScope {
  DurableScope({
    required this.businessId,
    required this.kind,
    this.warehouseId,
  }) {
    if ((kind == DurableScopeKind.businessWide && warehouseId != null) ||
        (kind == DurableScopeKind.warehouse && warehouseId == null)) {
      throw ArgumentError('Warehouse identity must exactly match scope kind.');
    }
  }

  factory DurableScope.fromExecutionContext(ExecutionContext context) {
    final business = context.business;
    final actor = context.session.remoteAuthUserIdentity;
    if (business == null ||
        actor == null ||
        !context.session.isVerifiedRemote ||
        actor != business.memberAuthUserId) {
      throw ArgumentError('Verified remote business context is required.');
    }
    final scope = business.scope;
    return DurableScope(
      businessId: business.businessId,
      kind: scope is WarehouseScope
          ? DurableScopeKind.warehouse
          : DurableScopeKind.businessWide,
      warehouseId: scope is WarehouseScope ? scope.warehouseId : null,
    );
  }

  final BusinessId businessId;
  final DurableScopeKind kind;
  final WarehouseId? warehouseId;

  bool sameAs(DurableScope other) =>
      businessId == other.businessId &&
      kind == other.kind &&
      warehouseId == other.warehouseId;
}

String payloadFingerprint(String payloadJson) {
  try {
    jsonDecode(payloadJson);
  } on Object {
    throw ArgumentError.value(
        payloadJson, 'payloadJson', 'Valid JSON required.');
  }
  return sha256.convert(utf8.encode(payloadJson)).toString();
}

String canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalValue(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalValue).toList(growable: false);
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  throw ArgumentError.value(value, 'value', 'JSON-compatible value required.');
}

void requireFingerprint(String payloadJson, String fingerprint) {
  final normalized = fingerprint.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized) ||
      payloadFingerprint(payloadJson) != normalized) {
    throw ArgumentError('Payload fingerprint does not match exact payload.');
  }
}

enum DurableOutboxState {
  pending,
  claimed,
  retryWait,
  acknowledgedPendingApply,
  completed,
  permanentFailure,
  conflict,
  cancelled,
}

enum DurableInboxState { received, applying, applied, conflict, rejected }

enum DurableErrorClass {
  connectivity,
  timeout,
  rateLimited,
  serverTransient,
  serializationConflict,
  authenticationRefreshRequired,
  unknownOutcome,
  validation,
  unsupportedPayloadVersion,
  authorizationDenied,
  scopeMismatch,
  fingerprintMismatch,
  businessRule,
  remoteConflict,
  reconciliationMismatch,
  staleClaimRecovered,
}

final class DurableOutboxEnvelope {
  DurableOutboxEnvelope({
    required this.operationId,
    required this.idempotencyKey,
    required this.scope,
    required this.actorAuthUserId,
    required this.deviceId,
    required this.sessionId,
    required String capturedRole,
    required String operationKind,
    required String aggregateType,
    this.aggregateId,
    required this.payloadSchemaVersion,
    required this.payloadJson,
    required String payloadFingerprint,
    this.baseEntityVersion,
    this.isDeletionIntent = false,
    required DateTime occurredAtUtc,
    this.businessDate,
    this.causalPredecessorOperationId,
  })  : capturedRole = capturedRole.trim(),
        operationKind = operationKind.trim(),
        aggregateType = aggregateType.trim(),
        payloadFingerprint = payloadFingerprint.trim().toLowerCase(),
        occurredAtUtc = requireUtcInstant(occurredAtUtc, 'occurredAtUtc') {
    if (idempotencyKey.trim().isEmpty ||
        this.capturedRole.isEmpty ||
        this.operationKind.isEmpty ||
        this.aggregateType.isEmpty ||
        payloadSchemaVersion < 1 ||
        (aggregateId != null && aggregateId!.trim().isEmpty)) {
      throw ArgumentError('The durable operation envelope is incomplete.');
    }
    requireFingerprint(payloadJson, this.payloadFingerprint);
    if (isDeletionIntent && baseEntityVersion == null) {
      throw ArgumentError('Deletion intent requires a base entity version.');
    }
  }

  factory DurableOutboxEnvelope.fromExecutionContext({
    required OperationId operationId,
    required String idempotencyKey,
    required ExecutionContext context,
    required String operationKind,
    required String aggregateType,
    String? aggregateId,
    required int payloadSchemaVersion,
    required String payloadJson,
    required String payloadFingerprint,
    EntityVersion? baseEntityVersion,
    bool isDeletionIntent = false,
    required DateTime occurredAtUtc,
    BusinessDate? businessDate,
    OperationId? causalPredecessorOperationId,
  }) {
    final business = context.business;
    final actor = context.session.remoteAuthUserIdentity;
    if (business == null ||
        actor == null ||
        !context.session.isVerifiedRemote) {
      throw ArgumentError('Verified remote business context is required.');
    }
    return DurableOutboxEnvelope(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      scope: DurableScope.fromExecutionContext(context),
      actorAuthUserId: actor,
      deviceId: context.deviceIdentity,
      sessionId: context.session.sessionId,
      capturedRole: business.role,
      operationKind: operationKind,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      payloadSchemaVersion: payloadSchemaVersion,
      payloadJson: payloadJson,
      payloadFingerprint: payloadFingerprint,
      baseEntityVersion: baseEntityVersion,
      isDeletionIntent: isDeletionIntent,
      occurredAtUtc: occurredAtUtc,
      businessDate: businessDate,
      causalPredecessorOperationId: causalPredecessorOperationId,
    );
  }

  final OperationId operationId;
  final String idempotencyKey;
  final DurableScope scope;
  final RemoteAuthUserId actorAuthUserId;
  final DeviceId deviceId;
  final SessionId sessionId;
  final String capturedRole;
  final String operationKind;
  final String aggregateType;
  final String? aggregateId;
  final int payloadSchemaVersion;
  final String payloadJson;
  final String payloadFingerprint;
  final EntityVersion? baseEntityVersion;
  final bool isDeletionIntent;
  final DateTime occurredAtUtc;
  final BusinessDate? businessDate;
  final OperationId? causalPredecessorOperationId;
}

final class DurableAcknowledgement {
  DurableAcknowledgement({
    required this.schemaVersion,
    required this.payloadJson,
    required String payloadFingerprint,
    this.serverResultId,
    required DateTime serverAcceptedAtUtc,
    this.acknowledgedEntityVersion,
  })  : payloadFingerprint = payloadFingerprint.trim().toLowerCase(),
        serverAcceptedAtUtc =
            requireUtcInstant(serverAcceptedAtUtc, 'serverAcceptedAtUtc') {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    requireFingerprint(payloadJson, this.payloadFingerprint);
  }

  final int schemaVersion;
  final String payloadJson;
  final String payloadFingerprint;
  final String? serverResultId;
  final DateTime serverAcceptedAtUtc;
  final EntityVersion? acknowledgedEntityVersion;
}

final class DurableOutboxOperation {
  const DurableOutboxOperation({
    required this.envelope,
    required this.state,
    required this.attemptCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.recordVersion,
    this.nextAttemptAtUtc,
    this.lastAttemptAtUtc,
    this.lastErrorClass,
    this.lastErrorCode,
    this.claimToken,
    this.leaseExpiresAtUtc,
    this.acknowledgement,
    this.conflictId,
  });

  final DurableOutboxEnvelope envelope;
  final DurableOutboxState state;
  final int attemptCount;
  final DateTime? nextAttemptAtUtc;
  final DateTime? lastAttemptAtUtc;
  final DurableErrorClass? lastErrorClass;
  final String? lastErrorCode;
  final String? claimToken;
  final DateTime? leaseExpiresAtUtc;
  final DurableAcknowledgement? acknowledgement;
  final String? conflictId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int recordVersion;
}

final class DurableInboxEnvelope {
  DurableInboxEnvelope({
    required String sourceAuthority,
    required this.sourceOperationId,
    required this.scope,
    required String operationKind,
    required String aggregateType,
    this.aggregateId,
    required this.payloadSchemaVersion,
    required this.payloadJson,
    required String payloadFingerprint,
    this.sourceActorAuthUserId,
    this.sourceDeviceId,
    this.remoteEntityVersion,
    this.deletionMetadata,
    required DateTime serverOccurredAtUtc,
  })  : sourceAuthority = sourceAuthority.trim(),
        operationKind = operationKind.trim(),
        aggregateType = aggregateType.trim(),
        payloadFingerprint = payloadFingerprint.trim().toLowerCase(),
        serverOccurredAtUtc =
            requireUtcInstant(serverOccurredAtUtc, 'serverOccurredAtUtc') {
    if (this.sourceAuthority.isEmpty ||
        this.operationKind.isEmpty ||
        this.aggregateType.isEmpty ||
        payloadSchemaVersion < 1) {
      throw ArgumentError('The inbound envelope is incomplete.');
    }
    requireFingerprint(payloadJson, this.payloadFingerprint);
    if (deletionMetadata != null &&
        (remoteEntityVersion == null ||
            deletionMetadata!.deletionVersion != remoteEntityVersion)) {
      throw ArgumentError(
          'Deletion evidence must match remote entity version.');
    }
  }

  final String sourceAuthority;
  final OperationId sourceOperationId;
  final DurableScope scope;
  final String operationKind;
  final String aggregateType;
  final String? aggregateId;
  final int payloadSchemaVersion;
  final String payloadJson;
  final String payloadFingerprint;
  final RemoteAuthUserId? sourceActorAuthUserId;
  final DeviceId? sourceDeviceId;
  final EntityVersion? remoteEntityVersion;
  final DeletionMetadata? deletionMetadata;
  final DateTime serverOccurredAtUtc;
}

final class DurableInboxOperation {
  const DurableInboxOperation({
    required this.envelope,
    required this.state,
    required this.applyAttemptCount,
    required this.receivedAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.recordVersion,
    this.lastApplyAttemptAtUtc,
    this.lastErrorClass,
    this.lastErrorCode,
    this.claimToken,
    this.leaseExpiresAtUtc,
    this.appliedAtUtc,
    this.rejectedAtUtc,
    this.conflictId,
  });

  final DurableInboxEnvelope envelope;
  final DurableInboxState state;
  final int applyAttemptCount;
  final DateTime receivedAtUtc;
  final DateTime? lastApplyAttemptAtUtc;
  final DurableErrorClass? lastErrorClass;
  final String? lastErrorCode;
  final String? claimToken;
  final DateTime? leaseExpiresAtUtc;
  final DateTime? appliedAtUtc;
  final DateTime? rejectedAtUtc;
  final String? conflictId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int recordVersion;
}

final class DurableCheckpoint {
  const DurableCheckpoint({
    required this.scope,
    required this.sourceAuthority,
    required this.streamName,
    required this.cursorValue,
    required this.updatedAtUtc,
    required this.recordVersion,
    this.lastSourceOperationId,
  });

  final DurableScope scope;
  final String sourceAuthority;
  final String streamName;
  final String cursorValue;
  final OperationId? lastSourceOperationId;
  final DateTime updatedAtUtc;
  final int recordVersion;
}

class DurableIdentityConflictException implements Exception {
  const DurableIdentityConflictException(this.code);
  final String code;
}

class DurableLostRaceException implements Exception {
  const DurableLostRaceException();
}
