import 'dart:convert';

import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:uuid/uuid.dart';

const productCatalogPayloadSchemaVersion = 1;
const productCatalogSourceAuthority = 'supabase.product_catalog.v1';
const productCatalogStreamName = 'product_catalog_changes_v1';
const productCatalogPullPageSize = 100;
const productCatalogMaxPullPagesPerPass = 5;
const productCatalogMaxOutboundPerPass = 25;

enum ProductCatalogMutationKind {
  create('product.create.v1'),
  update('product.update.v1'),
  setActive('product.setActive.v1');

  const ProductCatalogMutationKind(this.wireName);
  final String wireName;

  static ProductCatalogMutationKind fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value,
          orElse: () => throw ArgumentError.value(value, 'mutationKind'));
}

enum ProductCloudDisposition {
  localOnly,
  pending,
  acknowledged,
  attentionRequired,
  tombstoned,
}

final class ProductCatalogPayload {
  ProductCatalogPayload({
    this.schemaVersion = productCatalogPayloadSchemaVersion,
    required this.mutationKind,
    required String remoteProductId,
    this.legacyLocalId,
    required String name,
    String? code,
    required this.unit,
    required this.isActive,
    this.defaultSalePricePiastersPerKg,
    this.minimumSalePricePiastersPerKg,
    this.referenceCostPricePiastersPerKg,
    String? notes,
  })  : remoteProductId = _uuid(remoteProductId, 'remoteProductId'),
        name = name.trim(),
        code = _optional(code),
        notes = _optional(notes) {
    if (schemaVersion != productCatalogPayloadSchemaVersion ||
        this.name.isEmpty) {
      throw ArgumentError('Unsupported schema or empty product name.');
    }
    _positive(defaultSalePricePiastersPerKg, 'defaultSalePricePiastersPerKg');
    _positive(minimumSalePricePiastersPerKg, 'minimumSalePricePiastersPerKg');
    _positive(
        referenceCostPricePiastersPerKg, 'referenceCostPricePiastersPerKg');
    if (defaultSalePricePiastersPerKg != null &&
        minimumSalePricePiastersPerKg != null &&
        minimumSalePricePiastersPerKg! > defaultSalePricePiastersPerKg!) {
      throw ArgumentError('Minimum sale price cannot exceed default price.');
    }
  }

  factory ProductCatalogPayload.fromProduct({
    required ProductCatalogMutationKind mutationKind,
    required String remoteProductId,
    required Product product,
    String? legacyLocalId,
  }) =>
      ProductCatalogPayload(
        mutationKind: mutationKind,
        remoteProductId: remoteProductId,
        legacyLocalId: legacyLocalId,
        name: product.name,
        code: product.code,
        unit: product.unit,
        isActive: product.isActive,
        defaultSalePricePiastersPerKg: product.defaultSalePricePiastersPerKg,
        minimumSalePricePiastersPerKg: product.minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg:
            product.referenceCostPricePiastersPerKg,
        notes: product.notes,
      );

  factory ProductCatalogPayload.fromJson(Map<String, Object?> json) {
    const expected = <String>{
      'schemaVersion',
      'mutationKind',
      'remoteProductId',
      'legacyLocalId',
      'name',
      'code',
      'unit',
      'isActive',
      'defaultSalePricePiastersPerKg',
      'minimumSalePricePiastersPerKg',
      'referenceCostPricePiastersPerKg',
      'notes',
    };
    if (json.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Unexpected product payload fields.');
    }
    return ProductCatalogPayload(
      schemaVersion: _int(json, 'schemaVersion'),
      mutationKind: ProductCatalogMutationKind.fromWireName(
          _string(json, 'mutationKind')),
      remoteProductId: _string(json, 'remoteProductId'),
      legacyLocalId: _nullableString(json, 'legacyLocalId'),
      name: _string(json, 'name'),
      code: _nullableString(json, 'code'),
      unit: GrainUnit.fromWireName(_string(json, 'unit')),
      isActive: _bool(json, 'isActive'),
      defaultSalePricePiastersPerKg:
          _nullableInt(json, 'defaultSalePricePiastersPerKg'),
      minimumSalePricePiastersPerKg:
          _nullableInt(json, 'minimumSalePricePiastersPerKg'),
      referenceCostPricePiastersPerKg:
          _nullableInt(json, 'referenceCostPricePiastersPerKg'),
      notes: _nullableString(json, 'notes'),
    );
  }

  factory ProductCatalogPayload.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const FormatException('Object required.');
    return ProductCatalogPayload.fromJson(decoded.cast<String, Object?>());
  }

  final int schemaVersion;
  final ProductCatalogMutationKind mutationKind;
  final String remoteProductId;
  final String? legacyLocalId;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
  final int? defaultSalePricePiastersPerKg;
  final int? minimumSalePricePiastersPerKg;
  final int? referenceCostPricePiastersPerKg;
  final String? notes;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'mutationKind': mutationKind.wireName,
        'remoteProductId': remoteProductId,
        'legacyLocalId': legacyLocalId,
        'name': name,
        'code': code,
        'unit': unit.wireName,
        'isActive': isActive,
        'defaultSalePricePiastersPerKg': defaultSalePricePiastersPerKg,
        'minimumSalePricePiastersPerKg': minimumSalePricePiastersPerKg,
        'referenceCostPricePiastersPerKg': referenceCostPricePiastersPerKg,
        'notes': notes,
      };

  String get canonicalPayloadJson => canonicalJson(toJson());
  String get fingerprint => payloadFingerprint(canonicalPayloadJson);
}

final class ProductCatalogRemoteChange {
  ProductCatalogRemoteChange({
    required this.payload,
    required this.entityVersion,
    required this.sourceOperationId,
    required this.actorAuthUserId,
    required this.deviceId,
    required DateTime serverModifiedAtUtc,
    required this.changeCursor,
    this.deletionMetadata,
    this.replayed = false,
  }) : serverModifiedAtUtc =
            requireUtcInstant(serverModifiedAtUtc, 'serverModifiedAtUtc') {
    if (changeCursor < 1 ||
        (deletionMetadata != null &&
            deletionMetadata!.deletionVersion != entityVersion)) {
      throw ArgumentError('Invalid cursor or tombstone version.');
    }
  }

  factory ProductCatalogRemoteChange.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    if (rawPayload is! Map) throw const FormatException('Payload required.');
    final deletion = json['deletion'];
    return ProductCatalogRemoteChange(
      payload:
          ProductCatalogPayload.fromJson(rawPayload.cast<String, Object?>()),
      entityVersion: EntityVersion(_int(json, 'entityVersion')),
      sourceOperationId: OperationId(_string(json, 'sourceOperationId')),
      actorAuthUserId: RemoteAuthUserId(_string(json, 'actorAuthUserId')),
      deviceId: DeviceId(_string(json, 'deviceId')),
      serverModifiedAtUtc:
          DateTime.parse(_string(json, 'serverModifiedAtUtc')).toUtc(),
      changeCursor: _int(json, 'changeCursor'),
      deletionMetadata: deletion == null
          ? null
          : _deletionFromJson((deletion as Map).cast<String, Object?>()),
      replayed: json['replayed'] as bool? ?? false,
    );
  }

  final ProductCatalogPayload payload;
  final EntityVersion entityVersion;
  final OperationId sourceOperationId;
  final RemoteAuthUserId actorAuthUserId;
  final DeviceId deviceId;
  final DateTime serverModifiedAtUtc;
  final int changeCursor;
  final DeletionMetadata? deletionMetadata;
  final bool replayed;

  Map<String, Object?> toJson() => <String, Object?>{
        'payload': payload.toJson(),
        'entityVersion': entityVersion.value,
        'sourceOperationId': sourceOperationId.value,
        'actorAuthUserId': actorAuthUserId.value,
        'deviceId': deviceId.value,
        'serverModifiedAtUtc': serverModifiedAtUtc.toIso8601String(),
        'changeCursor': changeCursor,
        'deletion': deletionMetadata?.toJson(),
        'replayed': replayed,
      };

  String get canonicalResultJson => canonicalJson(toJson());
  String get resultFingerprint => payloadFingerprint(canonicalResultJson);
}

final class ProductCatalogPushRequest {
  const ProductCatalogPushRequest(this.operation);
  final DurableOutboxOperation operation;

  Map<String, Object?> toRpcParameters() => <String, Object?>{
        'p_business_id': operation.envelope.scope.businessId.value,
        'p_operation_id': operation.envelope.operationId.value,
        'p_idempotency_key': operation.envelope.idempotencyKey,
        'p_device_id': operation.envelope.deviceId.value,
        'p_operation_kind': operation.envelope.operationKind,
        'p_base_entity_version': operation.envelope.baseEntityVersion?.value,
        'p_payload': jsonDecode(operation.envelope.payloadJson),
        'p_payload_fingerprint': operation.envelope.payloadFingerprint,
      };
}

sealed class ProductCatalogPushOutcome {
  const ProductCatalogPushOutcome();
}

final class ProductCatalogPushAccepted extends ProductCatalogPushOutcome {
  const ProductCatalogPushAccepted(this.change);
  final ProductCatalogRemoteChange change;
}

final class ProductCatalogPushVersionConflict
    extends ProductCatalogPushOutcome {
  const ProductCatalogPushVersionConflict(this.code, this.remote);
  final String code;
  final ProductCatalogRemoteChange remote;
}

final class ProductCatalogPushPermanentFailure
    extends ProductCatalogPushOutcome {
  const ProductCatalogPushPermanentFailure(this.errorClass, this.code);
  final DurableErrorClass errorClass;
  final String code;
}

final class ProductCatalogPushRetryableFailure
    extends ProductCatalogPushOutcome {
  const ProductCatalogPushRetryableFailure(this.errorClass, this.code);
  final DurableErrorClass errorClass;
  final String code;
}

abstract interface class ProductCatalogPushGateway {
  Future<ProductCatalogPushOutcome> push(ProductCatalogPushRequest request);
}

abstract interface class ProductCatalogPullGateway {
  Future<List<ProductCatalogRemoteChange>> pull({
    required DurableScope scope,
    required int afterCursor,
    required int limit,
  });
}

String _uuid(String value, String name) {
  final normalized = value.trim().toLowerCase();
  if (!Uuid.isValidUUID(fromString: normalized)) {
    throw ArgumentError.value(value, name, 'UUID required.');
  }
  return normalized;
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

void _positive(int? value, String name) {
  if (value != null && value <= 0) throw ArgumentError.value(value, name);
}

String _string(Map json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _nullableString(Map json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _int(Map json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int? _nullableInt(Map json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _bool(Map json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

DeletionMetadata _deletionFromJson(Map<String, Object?> json) =>
    DeletionMetadata(
      deletionVersion: EntityVersion(_int(json, 'deletionVersion')),
      deletedAtUtc: DateTime.parse(_string(json, 'deletedAtUtc')).toUtc(),
      deletedByAuthUserId:
          RemoteAuthUserId(_string(json, 'deletedByAuthUserId')),
      deletedByDeviceId: DeviceId(_string(json, 'deletedByDeviceId')),
      sourceOperationId: OperationId(_string(json, 'sourceOperationId')),
    );
