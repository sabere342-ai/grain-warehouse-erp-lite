import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';

abstract interface class DurableConflictRepository {
  Future<DurableConflict> recordConflict(DurableConflictEvidence evidence);
  Future<DurableConflict?> loadConflict(String conflictId);
  Future<List<DurableConflict>> listUnresolvedConflicts(DurableScope scope);
  Future<DurableConflict> resolveConflict(
    String conflictId, {
    required DurableScope scope,
    required int expectedRecordVersion,
    required DurableConflictResolutionKind resolutionKind,
    required String resolutionOperationId,
    required String resolverAuthUserId,
    required DateTime resolvedAtUtc,
  });
}
