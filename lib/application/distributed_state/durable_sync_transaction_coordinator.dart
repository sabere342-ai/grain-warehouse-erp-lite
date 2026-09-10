import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';

abstract interface class DurableSyncTransactionCoordinator {
  Future<T> enqueueWithMutation<T>(
    DurableOutboxEnvelope envelope,
    Future<T> Function() mutation,
  );

  Future<T> applyInbound<T>(
    DurableScope scope,
    String sourceAuthority,
    String sourceOperationId, {
    required int expectedRecordVersion,
    required String claimToken,
    required Future<T> Function(DurableInboxEnvelope envelope) mutation,
    DurableCheckpoint? checkpoint,
  });
}
