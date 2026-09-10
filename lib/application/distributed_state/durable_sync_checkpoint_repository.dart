import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';

abstract interface class DurableSyncCheckpointRepository {
  Future<DurableCheckpoint?> loadCheckpoint(
    DurableScope scope,
    String sourceAuthority,
    String streamName,
  );
}
