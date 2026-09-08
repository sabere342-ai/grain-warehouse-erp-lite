import 'package:uuid/uuid.dart';

abstract interface class CanonicalUuidIdentity {
  String get value;
}

String _canonicalUuid(String value, String argumentName) {
  final normalized = value.trim().toLowerCase();
  if (!Uuid.isValidUUID(fromString: normalized)) {
    throw ArgumentError.value(value, argumentName, 'UUID required.');
  }
  return normalized;
}

String _canonicalUuidV4(String value, String argumentName) {
  final normalized = _canonicalUuid(value, argumentName);
  if (normalized[14] != '4') {
    throw ArgumentError.value(value, argumentName, 'UUIDv4 required.');
  }
  return normalized;
}

final class BusinessId implements CanonicalUuidIdentity {
  factory BusinessId(String value) =>
      BusinessId._(_canonicalUuid(value, 'businessId'));
  const BusinessId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) => other is BusinessId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class WarehouseId implements CanonicalUuidIdentity {
  factory WarehouseId(String value) =>
      WarehouseId._(_canonicalUuid(value, 'warehouseId'));
  const WarehouseId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) =>
      other is WarehouseId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class DeviceId implements CanonicalUuidIdentity {
  factory DeviceId(String value) =>
      DeviceId._(_canonicalUuidV4(value, 'deviceId'));
  const DeviceId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) => other is DeviceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class SessionId implements CanonicalUuidIdentity {
  factory SessionId(String value) =>
      SessionId._(_canonicalUuidV4(value, 'sessionId'));
  const SessionId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) => other is SessionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class RemoteAuthUserId implements CanonicalUuidIdentity {
  factory RemoteAuthUserId(String value) =>
      RemoteAuthUserId._(_canonicalUuid(value, 'remoteAuthUserId'));
  const RemoteAuthUserId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) =>
      other is RemoteAuthUserId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class LocalActorId {
  factory LocalActorId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        value,
        'localActorId',
        'Non-empty value required.',
      );
    }
    return LocalActorId._(normalized);
  }
  const LocalActorId._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is LocalActorId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class OperationId implements CanonicalUuidIdentity {
  factory OperationId(String value) =>
      OperationId._(_canonicalUuid(value, 'operationId'));
  const OperationId._(this.value);

  @override
  final String value;

  @override
  bool operator ==(Object other) =>
      other is OperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class BusinessScope {
  const BusinessScope();
}

final class BusinessWide extends BusinessScope {
  const BusinessWide();

  @override
  bool operator ==(Object other) => other is BusinessWide;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WarehouseScope extends BusinessScope {
  const WarehouseScope(this.warehouseId);

  final WarehouseId warehouseId;

  @override
  bool operator ==(Object other) =>
      other is WarehouseScope && other.warehouseId == warehouseId;

  @override
  int get hashCode => warehouseId.hashCode;
}

abstract interface class DeviceIdGenerator {
  DeviceId generate();
}

final class UuidV4DeviceIdGenerator implements DeviceIdGenerator {
  const UuidV4DeviceIdGenerator();

  @override
  DeviceId generate() => DeviceId(const Uuid().v4());
}

abstract interface class SessionIdGenerator {
  SessionId generate();
}

final class UuidV4SessionIdGenerator implements SessionIdGenerator {
  const UuidV4SessionIdGenerator();

  @override
  SessionId generate() => SessionId(const Uuid().v4());
}
