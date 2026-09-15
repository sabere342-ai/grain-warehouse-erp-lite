import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:uuid/uuid.dart';

final class ProductCatalogSyncCoordinator {
  ProductCatalogSyncCoordinator({
    required this.durableStore,
    required this.productStore,
    required this.pushGateway,
    required this.pullGateway,
    required this.executionContexts,
    required this.clock,
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  final DriftDurableSyncStore durableStore;
  final DriftProductCatalogSyncStore productStore;
  final ProductCatalogPushGateway pushGateway;
  final ProductCatalogPullGateway pullGateway;
  final ExecutionContextProvider executionContexts;
  final ApplicationClock clock;
  final Uuid _uuid;
  Future<void>? _activePass;

  Future<void> synchronizeOnce() {
    final active = _activePass;
    if (active != null) return active;
    final run = _run();
    _activePass = run;
    return run.whenComplete(() {
      if (identical(_activePass, run)) _activePass = null;
    });
  }

  Future<List<DurableConflict>> listUnresolvedForProduct(
    String localProductId,
  ) async {
    final binding = await _requireOwnerBinding();
    final state = await productStore.loadByLocalId(localProductId);
    if (state == null || state.businessId != binding.businessId.value) {
      return const [];
    }
    final conflicts = await durableStore.listUnresolvedConflicts(binding.scope);
    return conflicts
        .where((item) =>
            item.evidence.entityType == 'product' &&
            item.evidence.entityId == state.remoteProductId)
        .toList(growable: false);
  }

  Future<void> acceptServer({
    required String localProductId,
    required String conflictId,
    required int expectedRecordVersion,
  }) async {
    final binding = await _requireOwnerBinding();
    final conflict = await _requireProductConflict(
      binding,
      localProductId,
      conflictId,
      expectedRecordVersion,
    );
    final remote = ProductCatalogRemoteChange.fromJson(
      (jsonDecode(conflict.evidence.remotePayloadJson) as Map)
          .cast<String, dynamic>(),
    );
    final now = clock.nowUtc();
    final resolutionOperationId = _uuid.v4();
    await durableStore.database.inTransaction(() async {
      await productStore.acceptRemoteResolution(
        localProductId: localProductId,
        change: remote,
        businessId: binding.businessId.value,
        nowUtc: now,
      );
      final localOperationId = conflict.evidence.localOperationId?.value;
      if (localOperationId != null) {
        final operation =
            await durableStore.loadOutbox(binding.scope, localOperationId);
        if (operation == null ||
            operation.state != DurableOutboxState.conflict ||
            operation.conflictId != conflictId) {
          throw const DurableLostRaceException();
        }
        await durableStore.cancelConflictedOutbox(
          binding.scope,
          localOperationId,
          expectedRecordVersion: operation.recordVersion,
          conflictId: conflictId,
          cancelledAtUtc: now,
        );
      }
      await durableStore.resolveConflict(
        conflictId,
        scope: binding.scope,
        expectedRecordVersion: expectedRecordVersion,
        resolutionKind: DurableConflictResolutionKind.acceptRemote,
        resolutionOperationId: resolutionOperationId,
        resolverAuthUserId: binding.authUserId.value,
        resolvedAtUtc: now,
      );
      final related = await durableStore.listUnresolvedConflicts(binding.scope);
      for (final candidate in related) {
        if (candidate.evidence.classification !=
                DurableConflictClassification.duplicateNaturalKey ||
            candidate.evidence.entityId != remote.payload.remoteProductId ||
            candidate.evidence.localOperationId != null) {
          continue;
        }
        await durableStore.resolveConflict(
          candidate.evidence.conflictId,
          scope: binding.scope,
          expectedRecordVersion: candidate.recordVersion,
          resolutionKind: DurableConflictResolutionKind.acceptRemote,
          resolutionOperationId: resolutionOperationId,
          resolverAuthUserId: binding.authUserId.value,
          resolvedAtUtc: now,
        );
      }
    });
  }

  Future<void> resubmitLocal({
    required String localProductId,
    required String conflictId,
    required int expectedRecordVersion,
  }) async {
    final binding = await _requireOwnerBinding();
    final conflict = await _requireProductConflict(
      binding,
      localProductId,
      conflictId,
      expectedRecordVersion,
    );
    final oldOperationId = conflict.evidence.localOperationId?.value;
    final remoteVersion = conflict.evidence.remoteEntityVersion;
    if (oldOperationId == null || remoteVersion == null) {
      throw StateError('productCatalog.resubmitEvidenceMissing');
    }
    final oldOperation =
        await durableStore.loadOutbox(binding.scope, oldOperationId);
    final state = await productStore.loadByLocalId(localProductId);
    if (oldOperation == null ||
        oldOperation.state != DurableOutboxState.conflict ||
        oldOperation.conflictId != conflictId ||
        state == null ||
        state.pendingOperationId != oldOperationId) {
      throw const DurableLostRaceException();
    }
    final localPayload = ProductCatalogPayload.decode(
      conflict.evidence.localPayloadJson,
    );
    final isNaturalKeyConflict = conflict.evidence.classification ==
        DurableConflictClassification.duplicateNaturalKey;
    final remote = isNaturalKeyConflict
        ? ProductCatalogRemoteChange.fromJson(
            (jsonDecode(conflict.evidence.remotePayloadJson) as Map)
                .cast<String, dynamic>(),
          )
        : null;
    final payload = isNaturalKeyConflict
        ? ProductCatalogPayload(
            mutationKind: ProductCatalogMutationKind.update,
            remoteProductId: remote!.payload.remoteProductId,
            legacyLocalId: localPayload.legacyLocalId,
            name: localPayload.name,
            code: localPayload.code,
            unit: localPayload.unit,
            isActive: localPayload.isActive,
            defaultSalePricePiastersPerKg:
                localPayload.defaultSalePricePiastersPerKg,
            minimumSalePricePiastersPerKg:
                localPayload.minimumSalePricePiastersPerKg,
            referenceCostPricePiastersPerKg:
                localPayload.referenceCostPricePiastersPerKg,
            notes: localPayload.notes,
          )
        : localPayload;
    final now = clock.nowUtc();
    final replacementId = OperationId(_uuid.v4());
    final replacement = DurableOutboxEnvelope(
      operationId: replacementId,
      idempotencyKey: replacementId.value,
      scope: binding.scope,
      actorAuthUserId: binding.authUserId,
      deviceId: oldOperation.envelope.deviceId,
      sessionId: oldOperation.envelope.sessionId,
      capturedRole: binding.role,
      operationKind: payload.mutationKind.wireName,
      aggregateType: 'product',
      aggregateId: payload.remoteProductId,
      payloadSchemaVersion: productCatalogPayloadSchemaVersion,
      payloadJson: payload.canonicalPayloadJson,
      payloadFingerprint: payload.fingerprint,
      baseEntityVersion: remoteVersion,
      occurredAtUtc: now,
    );
    await durableStore.enqueueWithMutation<void>(replacement, () async {
      if (isNaturalKeyConflict) {
        await productStore.rebindRemoteIdentity(
          state: state,
          remoteProductId: payload.remoteProductId,
          nowUtc: now,
        );
      }
      await productStore.replaceConflictPending(
        state: state,
        expectedPendingOperationId: oldOperationId,
        replacementOperationId: replacementId.value,
        nowUtc: now,
      );
    });
    unawaited(synchronizeOnce());
  }

  Future<ProductCatalogScopeBinding> _requireOwnerBinding() async {
    final binding = await productStore.loadActiveBinding();
    final context = executionContexts.current;
    if (binding == null ||
        !binding.canMutate ||
        context?.business?.businessId != binding.businessId ||
        context?.session.remoteAuthUserIdentity != binding.authUserId) {
      throw StateError('productCatalog.ownerBindingRequired');
    }
    return binding;
  }

  Future<DurableConflict> _requireProductConflict(
    ProductCatalogScopeBinding binding,
    String localProductId,
    String conflictId,
    int expectedRecordVersion,
  ) async {
    final state = await productStore.loadByLocalId(localProductId);
    final conflict = await durableStore.loadConflict(conflictId);
    if (state == null ||
        state.businessId != binding.businessId.value ||
        conflict == null ||
        conflict.resolutionState != DurableConflictResolutionState.unresolved ||
        conflict.recordVersion != expectedRecordVersion ||
        !conflict.evidence.scope.sameAs(binding.scope) ||
        conflict.evidence.entityType != 'product' ||
        conflict.evidence.entityId != state.remoteProductId) {
      throw const DurableLostRaceException();
    }
    return conflict;
  }

  Future<void> _run() async {
    final binding = await productStore.loadActiveBinding();
    final context = executionContexts.current;
    if (binding == null ||
        context?.business?.businessId != binding.businessId ||
        context?.session.remoteAuthUserIdentity != binding.authUserId) {
      return;
    }
    final now = clock.nowUtc();
    await durableStore.recoverExpiredOutboxClaims(now);
    await durableStore.recoverExpiredInboxClaims(now);
    await _repairAcknowledgements(binding);
    await _push(binding);
    await _pull(binding);
  }

  Future<void> _repairAcknowledgements(
    ProductCatalogScopeBinding binding,
  ) async {
    final rows = await (durableStore.database
            .select(durableStore.database.durableOutboxOperations)
          ..where((row) =>
              row.businessId.equals(binding.businessId.value) &
              row.scopeKind.equals(DurableScopeKind.businessWide.name) &
              row.aggregateType.equals('product') &
              row.state.equals(
                DurableOutboxState.acknowledgedPendingApply.name,
              )))
        .get();
    for (final row in rows) {
      final operation = await durableStore.loadOutbox(
        binding.scope,
        row.operationId,
      );
      if (operation != null) await _projectAcknowledgement(operation);
    }
  }

  Future<void> _push(ProductCatalogScopeBinding binding) async {
    final eligible = (await durableStore.listEligibleOutbox(
      binding.scope,
      clock.nowUtc(),
    ))
        .where((item) => item.envelope.aggregateType == 'product')
        .take(productCatalogMaxOutboundPerPass)
        .toList(growable: false);
    for (final candidate in eligible) {
      final claimed = await durableStore.claimOutbox(
        binding.scope,
        candidate.envelope.operationId.value,
        nowUtc: clock.nowUtc(),
        leaseDuration: const Duration(minutes: 2),
      );
      final outcome =
          await pushGateway.push(ProductCatalogPushRequest(claimed));
      switch (outcome) {
        case ProductCatalogPushAccepted(:final change):
          final acknowledgement = DurableAcknowledgement(
            schemaVersion: productCatalogPayloadSchemaVersion,
            payloadJson: change.canonicalResultJson,
            payloadFingerprint: change.resultFingerprint,
            serverResultId: change.payload.remoteProductId,
            serverAcceptedAtUtc: change.serverModifiedAtUtc,
            acknowledgedEntityVersion: change.entityVersion,
          );
          await durableStore.acknowledgeOutbox(
            binding.scope,
            claimed.envelope.operationId.value,
            expectedRecordVersion: claimed.recordVersion,
            claimToken: claimed.claimToken!,
            acknowledgement: acknowledgement,
          );
          final acknowledged = await durableStore.loadOutbox(
            binding.scope,
            claimed.envelope.operationId.value,
          );
          await _projectAcknowledgement(acknowledged!);
        case ProductCatalogPushVersionConflict(:final code, :final remote):
          await _conflictOutbound(claimed, remote, code);
        case ProductCatalogPushPermanentFailure(:final errorClass, :final code):
          await durableStore.database.inTransaction(() async {
            final state = await productStore.loadByRemoteId(
              binding.businessId.value,
              claimed.envelope.aggregateId!,
            );
            if (state != null) {
              await productStore.markAttention(
                state.localProductId,
                clock.nowUtc(),
              );
            }
            await durableStore.failOutboxPermanently(
              binding.scope,
              claimed.envelope.operationId.value,
              expectedRecordVersion: claimed.recordVersion,
              claimToken: claimed.claimToken!,
              errorClass: errorClass,
              errorCode: code,
            );
          });
        case ProductCatalogPushRetryableFailure(:final errorClass, :final code):
          await durableStore.retryOutbox(
            binding.scope,
            claimed.envelope.operationId.value,
            expectedRecordVersion: claimed.recordVersion,
            claimToken: claimed.claimToken!,
            nextAttemptAtUtc:
                clock.nowUtc().add(_retryDelay(claimed.attemptCount)),
            errorClass: errorClass,
            errorCode: code,
          );
      }
    }
  }

  Future<void> _projectAcknowledgement(
    DurableOutboxOperation operation,
  ) async {
    final acknowledgement = operation.acknowledgement;
    if (acknowledgement == null) {
      throw StateError('productCatalog.acknowledgementMissing');
    }
    try {
      final decoded = jsonDecode(acknowledgement.payloadJson);
      final change = ProductCatalogRemoteChange.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      );
      if (change.payload.remoteProductId != operation.envelope.aggregateId ||
          change.entityVersion != acknowledgement.acknowledgedEntityVersion) {
        throw StateError('productCatalog.acknowledgementMismatch');
      }
      await durableStore.database.inTransaction(() async {
        await productStore.applyAcknowledgement(
          change,
          operation.envelope.operationId.value,
          clock.nowUtc(),
        );
        await durableStore.completeOutbox(
          operation.envelope.scope,
          operation.envelope.operationId.value,
          expectedRecordVersion: operation.recordVersion,
        );
        await _resolveResubmittedConflicts(operation, change);
      });
    } on Object {
      final payload = ProductCatalogPayload.decode(
        operation.envelope.payloadJson,
      );
      await _conflictOutbound(
        operation,
        ProductCatalogRemoteChange(
          payload: payload,
          entityVersion:
              operation.envelope.baseEntityVersion ?? EntityVersion.initial,
          sourceOperationId: operation.envelope.operationId,
          actorAuthUserId: operation.envelope.actorAuthUserId,
          deviceId: operation.envelope.deviceId,
          serverModifiedAtUtc: clock.nowUtc(),
          changeCursor: 1,
        ),
        'acknowledgedProjectionMismatch',
      );
    }
  }

  Future<void> _resolveResubmittedConflicts(
    DurableOutboxOperation operation,
    ProductCatalogRemoteChange change,
  ) async {
    final unresolved =
        await durableStore.listUnresolvedConflicts(operation.envelope.scope);
    for (final conflict in unresolved) {
      final isExactResubmission =
          conflict.evidence.entityId == change.payload.remoteProductId &&
              conflict.evidence.localPayloadFingerprint ==
                  change.payload.fingerprint;
      final isNaturalKeyResubmission = conflict.evidence.classification ==
              DurableConflictClassification.duplicateNaturalKey &&
          conflict.evidence.localOperationId != null &&
          _sameProductCandidate(
            ProductCatalogPayload.decode(conflict.evidence.localPayloadJson),
            change.payload,
          );
      final isRelatedInboundNaturalKeyConflict =
          conflict.evidence.classification ==
                  DurableConflictClassification.duplicateNaturalKey &&
              conflict.evidence.entityId == change.payload.remoteProductId &&
              conflict.evidence.localOperationId == null;
      if (conflict.evidence.entityType != 'product' ||
          (!isExactResubmission &&
              !isNaturalKeyResubmission &&
              !isRelatedInboundNaturalKeyConflict) ||
          conflict.evidence.localOperationId ==
              operation.envelope.operationId) {
        continue;
      }
      await durableStore.resolveConflict(
        conflict.evidence.conflictId,
        scope: operation.envelope.scope,
        expectedRecordVersion: conflict.recordVersion,
        resolutionKind: DurableConflictResolutionKind.resubmitLocal,
        resolutionOperationId: operation.envelope.operationId.value,
        resolverAuthUserId: operation.envelope.actorAuthUserId.value,
        resolvedAtUtc: clock.nowUtc(),
      );
    }
  }

  bool _sameProductCandidate(
    ProductCatalogPayload local,
    ProductCatalogPayload acknowledged,
  ) =>
      local.legacyLocalId == acknowledged.legacyLocalId &&
      local.name == acknowledged.name &&
      local.code == acknowledged.code &&
      local.unit == acknowledged.unit &&
      local.isActive == acknowledged.isActive &&
      local.defaultSalePricePiastersPerKg ==
          acknowledged.defaultSalePricePiastersPerKg &&
      local.minimumSalePricePiastersPerKg ==
          acknowledged.minimumSalePricePiastersPerKg &&
      local.referenceCostPricePiastersPerKg ==
          acknowledged.referenceCostPricePiastersPerKg &&
      local.notes == acknowledged.notes;

  Future<void> _conflictOutbound(
    DurableOutboxOperation operation,
    ProductCatalogRemoteChange remote,
    String code,
  ) async {
    final classification = switch (code) {
      'duplicateNaturalKey' =>
        DurableConflictClassification.duplicateNaturalKey,
      'deleteVsUpdate' => DurableConflictClassification.deleteVsUpdate,
      'acknowledgedProjectionMismatch' =>
        DurableConflictClassification.acknowledgedProjectionMismatch,
      _ => DurableConflictClassification.versionMismatch,
    };
    final evidence = DurableConflictEvidence(
      conflictId: _uuid.v4(),
      scope: operation.envelope.scope,
      entityType: 'product',
      entityId: operation.envelope.aggregateId!,
      localEntityVersion: operation.envelope.baseEntityVersion,
      remoteEntityVersion: remote.entityVersion,
      localPayloadJson: operation.envelope.payloadJson,
      remotePayloadJson: remote.canonicalResultJson,
      localOperationId: operation.envelope.operationId,
      remoteOperationId: remote.sourceOperationId,
      remoteSourceAuthority: productCatalogSourceAuthority,
      remoteDeletionMetadata: remote.deletionMetadata,
      classification: classification,
      detectedAtUtc: clock.nowUtc(),
    );
    await durableStore.database.inTransaction(() async {
      final state = await productStore.loadByRemoteId(
        operation.envelope.scope.businessId.value,
        operation.envelope.aggregateId!,
      );
      if (state != null) {
        await productStore.markAttention(state.localProductId, clock.nowUtc());
      }
      await durableStore.conflictOutbox(
        operation.envelope.scope,
        operation.envelope.operationId.value,
        expectedRecordVersion: operation.recordVersion,
        evidence: evidence,
      );
    });
  }

  Future<void> _pull(ProductCatalogScopeBinding binding) async {
    for (var page = 0; page < productCatalogMaxPullPagesPerPass; page++) {
      final checkpoint = await durableStore.loadCheckpoint(
        binding.scope,
        productCatalogSourceAuthority,
        productCatalogStreamName,
      );
      final after = int.tryParse(checkpoint?.cursorValue ?? '0') ?? 0;
      final changes = await pullGateway.pull(
        scope: binding.scope,
        afterCursor: after,
        limit: productCatalogPullPageSize,
      );
      if (changes.isEmpty) {
        await durableStore.recordSuccessfulPull(
          binding.scope,
          productCatalogSourceAuthority,
          productCatalogStreamName,
          clock.nowUtc(),
        );
        return;
      }
      for (final change in changes) {
        await _receiveAndApply(binding, change);
      }
      if (changes.length < productCatalogPullPageSize) return;
    }
  }

  Future<void> _receiveAndApply(
    ProductCatalogScopeBinding binding,
    ProductCatalogRemoteChange change,
  ) async {
    final payloadJson = change.canonicalResultJson;
    final envelope = DurableInboxEnvelope(
      sourceAuthority: productCatalogSourceAuthority,
      sourceOperationId: change.sourceOperationId,
      scope: binding.scope,
      operationKind: change.payload.mutationKind.wireName,
      aggregateType: 'product',
      aggregateId: change.payload.remoteProductId,
      payloadSchemaVersion: productCatalogPayloadSchemaVersion,
      payloadJson: payloadJson,
      payloadFingerprint: payloadFingerprint(payloadJson),
      sourceActorAuthUserId: change.actorAuthUserId,
      sourceDeviceId: change.deviceId,
      remoteEntityVersion: change.entityVersion,
      deletionMetadata: change.deletionMetadata,
      serverOccurredAtUtc: change.serverModifiedAtUtc,
    );
    final received = await durableStore.receive(envelope);
    if (received.state != DurableInboxState.received) return;
    final claimed = await durableStore.claimInbox(
      binding.scope,
      productCatalogSourceAuthority,
      change.sourceOperationId.value,
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 2),
    );
    final state = await productStore.loadByRemoteId(
      binding.businessId.value,
      change.payload.remoteProductId,
    );
    final sameVersionMismatch =
        state?.acknowledgedEntityVersion == change.entityVersion.value &&
            state?.acknowledgedPayloadFingerprint != null &&
            state!.acknowledgedPayloadFingerprint != change.payload.fingerprint;
    final pendingConflict = state?.pendingOperationId != null;
    final checkpoint = DurableCheckpoint(
      scope: binding.scope,
      sourceAuthority: productCatalogSourceAuthority,
      streamName: productCatalogStreamName,
      cursorValue: change.changeCursor.toString(),
      lastSourceOperationId: change.sourceOperationId,
      updatedAtUtc: clock.nowUtc(),
      recordVersion: 1,
    );
    if (sameVersionMismatch || pendingConflict) {
      final pendingOperation = state?.pendingOperationId == null
          ? null
          : await durableStore.loadOutbox(
              binding.scope,
              state!.pendingOperationId!,
            );
      final localPayload = pendingOperation?.envelope.payloadJson ??
          state?.acknowledgedPayloadJson ??
          canonicalJson(<String, Object?>{});
      final evidence = DurableConflictEvidence(
        conflictId: _uuid.v4(),
        scope: binding.scope,
        entityType: 'product',
        entityId: change.payload.remoteProductId,
        localEntityVersion: pendingOperation?.envelope.baseEntityVersion ??
            (state?.acknowledgedEntityVersion == null
                ? null
                : EntityVersion(state!.acknowledgedEntityVersion!)),
        remoteEntityVersion: change.entityVersion,
        localPayloadJson: localPayload,
        remotePayloadJson: change.canonicalResultJson,
        localOperationId: state?.pendingOperationId == null
            ? null
            : OperationId(state!.pendingOperationId!),
        remoteOperationId: change.sourceOperationId,
        remoteSourceAuthority: productCatalogSourceAuthority,
        remoteDeletionMetadata: change.deletionMetadata,
        classification: change.deletionMetadata != null && pendingConflict
            ? DurableConflictClassification.deleteVsUpdate
            : pendingConflict
                ? DurableConflictClassification.versionMismatch
                : DurableConflictClassification.payloadMismatchAtSameVersion,
        detectedAtUtc: clock.nowUtc(),
      );
      await durableStore.database.inTransaction(() async {
        if (state != null) {
          await productStore.markAttention(
              state.localProductId, clock.nowUtc());
        }
        await durableStore.conflictInbox(
          binding.scope,
          productCatalogSourceAuthority,
          change.sourceOperationId.value,
          expectedRecordVersion: claimed.recordVersion,
          claimToken: claimed.claimToken!,
          evidence: evidence,
          checkpoint: checkpoint,
        );
      });
      return;
    }
    try {
      await durableStore.applyInbound<void>(
        binding.scope,
        productCatalogSourceAuthority,
        change.sourceOperationId.value,
        expectedRecordVersion: claimed.recordVersion,
        claimToken: claimed.claimToken!,
        mutation: (_) => productStore.applyInbound(
          change,
          binding.businessId.value,
          clock.nowUtc(),
        ),
        checkpoint: checkpoint,
      );
    } on Object {
      final evidence = DurableConflictEvidence(
        conflictId: _uuid.v4(),
        scope: binding.scope,
        entityType: 'product',
        entityId: change.payload.remoteProductId,
        localPayloadJson: canonicalJson(<String, Object?>{}),
        remotePayloadJson: change.canonicalResultJson,
        remoteEntityVersion: change.entityVersion,
        remoteOperationId: change.sourceOperationId,
        remoteSourceAuthority: productCatalogSourceAuthority,
        remoteDeletionMetadata: change.deletionMetadata,
        classification: DurableConflictClassification.duplicateNaturalKey,
        detectedAtUtc: clock.nowUtc(),
      );
      await durableStore.conflictInbox(
        binding.scope,
        productCatalogSourceAuthority,
        change.sourceOperationId.value,
        expectedRecordVersion: claimed.recordVersion,
        claimToken: claimed.claimToken!,
        evidence: evidence,
        checkpoint: checkpoint,
      );
    }
  }

  Duration _retryDelay(int attemptCount) {
    final exponent = attemptCount.clamp(1, 8);
    return Duration(seconds: 1 << exponent);
  }
}
