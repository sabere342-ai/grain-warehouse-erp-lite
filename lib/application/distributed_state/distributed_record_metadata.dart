import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';

final class EntityVersion implements Comparable<EntityVersion> {
  factory EntityVersion(int value) {
    if (value < 1 || value > maxValue) {
      throw ArgumentError.value(value, 'entityVersion');
    }
    return EntityVersion._(value);
  }

  const EntityVersion._(this.value);

  static const int maxValue = 9223372036854775807;
  static const EntityVersion initial = EntityVersion._(1);

  final int value;

  EntityVersion nextAcceptedMutation() {
    if (value == maxValue) {
      throw StateError('Entity version overflow.');
    }
    return EntityVersion._(value + 1);
  }

  @override
  int compareTo(EntityVersion other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is EntityVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

final class DeletionMetadata {
  DeletionMetadata({
    required this.deletionVersion,
    required DateTime deletedAtUtc,
    required this.deletedByAuthUserId,
    required this.deletedByDeviceId,
    required this.sourceOperationId,
  }) : deletedAtUtc = requireUtcInstant(deletedAtUtc, 'deletedAtUtc');

  final bool deleted = true;
  final EntityVersion deletionVersion;
  final DateTime deletedAtUtc;
  final RemoteAuthUserId deletedByAuthUserId;
  final DeviceId deletedByDeviceId;
  final OperationId sourceOperationId;

  Map<String, Object> toJson() => <String, Object>{
        'deleted': true,
        'deletionVersion': deletionVersion.value,
        'deletedAtUtc': deletedAtUtc.toIso8601String(),
        'deletedByAuthUserId': deletedByAuthUserId.value,
        'deletedByDeviceId': deletedByDeviceId.value,
        'sourceOperationId': sourceOperationId.value,
      };
}

final class DistributedRecordMetadata {
  DistributedRecordMetadata({
    required this.businessId,
    required this.entityType,
    required this.entityId,
    required this.entityVersion,
    required DateTime serverModifiedAtUtc,
    required this.modifiedByAuthUserId,
    required this.modifiedByDeviceId,
    required this.sourceOperationId,
    this.deletionMetadata,
  }) : serverModifiedAtUtc =
            requireUtcInstant(serverModifiedAtUtc, 'serverModifiedAtUtc') {
    if (entityType.trim().isEmpty || entityId.trim().isEmpty) {
      throw ArgumentError('Entity type and ID must be non-empty.');
    }
    if (deletionMetadata != null &&
        deletionMetadata!.deletionVersion != entityVersion) {
      throw ArgumentError('Deletion version must equal the record version.');
    }
  }

  final BusinessId businessId;
  final String entityType;
  final String entityId;
  final EntityVersion entityVersion;
  final DateTime serverModifiedAtUtc;
  final RemoteAuthUserId modifiedByAuthUserId;
  final DeviceId modifiedByDeviceId;
  final OperationId sourceOperationId;
  final DeletionMetadata? deletionMetadata;

  bool get isDeleted => deletionMetadata != null;
}
