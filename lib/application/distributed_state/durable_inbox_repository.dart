import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';

abstract interface class DurableInboxRepository {
  Future<DurableInboxOperation> receive(DurableInboxEnvelope envelope);
  Future<DurableInboxOperation?> loadInbox(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId,
  );
  Future<DurableInboxOperation?> claimNextInbox(
    DurableScope scope, {
    required DateTime nowUtc,
    required Duration leaseDuration,
  });
  Future<int> recoverExpiredInboxClaims(DateTime nowUtc);
  Future<DurableConflict> conflictInbox(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required DurableConflictEvidence evidence,
    DurableCheckpoint? checkpoint,
  });
}
