import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProductCatalogPushGateway
    implements ProductCatalogPushGateway {
  const SupabaseProductCatalogPushGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<ProductCatalogPushOutcome> push(
    ProductCatalogPushRequest request,
  ) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      return const ProductCatalogPushPermanentFailure(
        DurableErrorClass.authenticationRefreshRequired,
        'unauthenticated.sessionRequired',
      );
    }
    try {
      final response = await _client.rpc(
        'apply_product_catalog_operation_v1',
        params: request.toRpcParameters(),
      );
      if (response is! Map) return _unexpected();
      final json = response.cast<String, dynamic>();
      if (json['ok'] == true) {
        return ProductCatalogPushAccepted(
          ProductCatalogRemoteChange.fromJson(json),
        );
      }
      final code = _stableCode(json['code']);
      switch (json['outcome']) {
        case 'versionConflict':
          final remote = json['remote'];
          if (remote is! Map) return _unexpected();
          return ProductCatalogPushVersionConflict(
            code,
            ProductCatalogRemoteChange.fromJson(
              remote.cast<String, dynamic>(),
            ),
          );
        case 'retryableFailure':
          return ProductCatalogPushRetryableFailure(
            _errorClass(code),
            code,
          );
        default:
          return ProductCatalogPushPermanentFailure(
            _errorClass(code),
            code,
          );
      }
    } on TimeoutException {
      return const ProductCatalogPushRetryableFailure(
        DurableErrorClass.timeout,
        'serverTimeout',
      );
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const ProductCatalogPushPermanentFailure(
          DurableErrorClass.authorizationDenied,
          'unauthorized.productCatalogMutationDenied',
        );
      }
      if (error.code?.startsWith('08') == true ||
          error.code == 'PGRST000' ||
          error.code == 'PGRST002') {
        return const ProductCatalogPushRetryableFailure(
          DurableErrorClass.connectivity,
          'serverUnavailable',
        );
      }
      return const ProductCatalogPushRetryableFailure(
        DurableErrorClass.serverTransient,
        'transactionFailure',
      );
    } on FormatException {
      return _unexpected();
    } on ArgumentError {
      return _unexpected();
    } on Object {
      return const ProductCatalogPushRetryableFailure(
        DurableErrorClass.unknownOutcome,
        'unknownRemoteOutcome',
      );
    }
  }

  ProductCatalogPushOutcome _unexpected() =>
      const ProductCatalogPushPermanentFailure(
        DurableErrorClass.serializationConflict,
        'malformedServerResponse',
      );

  String _stableCode(Object? value) {
    final code = value is String ? value : 'unexpectedServerError';
    return _stableCodes.contains(code) ? code : 'unexpectedServerError';
  }

  DurableErrorClass _errorClass(String code) {
    if (code.startsWith('validation.')) return DurableErrorClass.validation;
    if (code.startsWith('unauthenticated.')) {
      return DurableErrorClass.authenticationRefreshRequired;
    }
    if (code.startsWith('unauthorized.')) {
      return DurableErrorClass.authorizationDenied;
    }
    return switch (code) {
      'fingerprintMismatch' => DurableErrorClass.fingerprintMismatch,
      'idempotencyConflict' => DurableErrorClass.serializationConflict,
      'versionMismatch' ||
      'deleteVsUpdate' ||
      'duplicateNaturalKey' =>
        DurableErrorClass.remoteConflict,
      'serverTimeout' => DurableErrorClass.timeout,
      'serverUnavailable' => DurableErrorClass.connectivity,
      'transactionFailure' => DurableErrorClass.serverTransient,
      _ => DurableErrorClass.unknownOutcome,
    };
  }

  static const _stableCodes = <String>{
    'validation.invalidField',
    'unauthenticated.sessionRequired',
    'unauthorized.productCatalogMutationDenied',
    'fingerprintMismatch',
    'idempotencyConflict',
    'versionMismatch',
    'deleteVsUpdate',
    'duplicateNaturalKey',
    'product.notFound',
    'serverTimeout',
    'serverUnavailable',
    'transactionFailure',
    'unexpectedServerError',
  };
}

final class SupabaseProductCatalogPullGateway
    implements ProductCatalogPullGateway {
  const SupabaseProductCatalogPullGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ProductCatalogRemoteChange>> pull({
    required DurableScope scope,
    required int afterCursor,
    required int limit,
  }) async {
    if (scope.kind != DurableScopeKind.businessWide ||
        scope.warehouseId != null ||
        afterCursor < 0 ||
        limit < 1 ||
        limit > productCatalogPullPageSize) {
      throw ArgumentError('Invalid product catalog pull request.');
    }
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      throw StateError('unauthenticated.sessionRequired');
    }
    final response = await _client.rpc(
      'pull_product_catalog_changes_v1',
      params: <String, Object?>{
        'p_business_id': scope.businessId.value,
        'p_after_cursor': afterCursor,
        'p_limit': limit,
      },
    );
    if (response is! List) {
      throw const FormatException('Product pull response must be a list.');
    }
    final changes = response.map((item) {
      if (item is! Map) {
        throw const FormatException('Product change must be an object.');
      }
      return ProductCatalogRemoteChange.fromJson(
        item.cast<String, dynamic>(),
      );
    }).toList(growable: false);
    for (var index = 1; index < changes.length; index++) {
      if (changes[index - 1].changeCursor >= changes[index].changeCursor) {
        throw const FormatException('Product changes are not ordered.');
      }
    }
    return changes;
  }
}

final class UnavailableProductCatalogPushGateway
    implements ProductCatalogPushGateway {
  const UnavailableProductCatalogPushGateway();

  @override
  Future<ProductCatalogPushOutcome> push(
    ProductCatalogPushRequest request,
  ) async =>
      const ProductCatalogPushRetryableFailure(
        DurableErrorClass.connectivity,
        'serverUnavailable',
      );
}

final class UnavailableProductCatalogPullGateway
    implements ProductCatalogPullGateway {
  const UnavailableProductCatalogPullGateway();

  @override
  Future<List<ProductCatalogRemoteChange>> pull({
    required DurableScope scope,
    required int afterCursor,
    required int limit,
  }) async =>
      const [];
}
