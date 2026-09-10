import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';

abstract interface class DurableOutboxRepository {
  Future<DurableOutboxOperation> enqueue(DurableOutboxEnvelope envelope);
  Future<DurableOutboxOperation?> loadOutbox(
    DurableScope scope,
    String operationId,
  );
  Future<List<DurableOutboxOperation>> listEligibleOutbox(
    DurableScope scope,
    DateTime nowUtc,
  );
  Future<DurableOutboxOperation?> claimNextOutbox(
    DurableScope scope, {
    required DateTime nowUtc,
    required Duration leaseDuration,
  });
  Future<void> retryOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DateTime nextAttemptAtUtc,
    required DurableErrorClass errorClass,
    required String errorCode,
  });
  Future<void> acknowledgeOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableAcknowledgement acknowledgement,
  });
  Future<void> completeOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
  });
  Future<int> recoverExpiredOutboxClaims(DateTime nowUtc);
  Future<DurableConflict> conflictOutbox(
    DurableScope scope,
    String operationId, {
    required int expectedRecordVersion,
    required DurableConflictEvidence evidence,
  });
}
