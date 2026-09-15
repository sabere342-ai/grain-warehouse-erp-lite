import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:uuid/uuid.dart';

final class CloudHybridProductRepository implements ProductDataRepository {
  CloudHybridProductRepository({
    required DriftProductRepository localRepository,
    required DriftProductCatalogSyncStore syncStore,
    required DriftDurableSyncStore durableStore,
    required ExecutionContextProvider executionContextProvider,
    required ApplicationClock clock,
    required DeviceId deviceIdentity,
    required bool cloudModeEnabled,
    required String? Function() currentRemoteAuthUserId,
    Future<void> Function()? requestSync,
    Uuid uuid = const Uuid(),
  })  : _local = localRepository,
        _syncStore = syncStore,
        _durableStore = durableStore,
        _contexts = executionContextProvider,
        _clock = clock,
        _deviceIdentity = deviceIdentity,
        _cloudModeEnabled = cloudModeEnabled,
        _currentRemoteAuthUserId = currentRemoteAuthUserId,
        _requestSync = requestSync,
        _uuid = uuid;

  final DriftProductRepository _local;
  final DriftProductCatalogSyncStore _syncStore;
  final DriftDurableSyncStore _durableStore;
  final ExecutionContextProvider _contexts;
  final ApplicationClock _clock;
  final DeviceId _deviceIdentity;
  final bool _cloudModeEnabled;
  final String? Function() _currentRemoteAuthUserId;
  final Future<void> Function()? _requestSync;
  final Uuid _uuid;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) =>
      _local.listProducts(includeInactive: includeInactive);

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    if (!_cloudModeEnabled) return _local.createProduct(draft);
    final binding = await _requireOwnerBinding();
    final now = _clock.nowUtc();
    final operationId = OperationId(_uuid.v4());
    final remoteId = _uuid.v4();
    final candidate = Product(
      id: remoteId,
      name: draft.name.trim(),
      code: _optional(draft.code),
      unit: draft.unit,
      isActive: true,
      defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg: draft.referenceCostPricePiastersPerKg,
      notes: _optional(draft.notes),
      createdAt: now.toLocal(),
      updatedAt: now.toLocal(),
    );
    final payload = ProductCatalogPayload.fromProduct(
      mutationKind: ProductCatalogMutationKind.create,
      remoteProductId: remoteId,
      product: candidate,
    );
    final envelope = _envelope(
      binding,
      operationId,
      payload,
      baseVersion: null,
      nowUtc: now,
    );
    final product = await _durableStore.enqueueWithMutation(
      envelope,
      () async {
        final created = await _local.createProductWithId(
          draft,
          id: remoteId,
          createdAt: now.toLocal(),
        );
        await _syncStore.createPending(
          localProductId: created.id,
          businessId: binding.businessId.value,
          remoteProductId: remoteId,
          operationId: operationId.value,
          nowUtc: now,
        );
        return created;
      },
    );
    _triggerSync();
    return product;
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) async {
    if (!_cloudModeEnabled) {
      return _local.updateProduct(productId: productId, draft: draft);
    }
    final binding = await _requireOwnerBinding();
    final state = await _requireMutableState(productId, binding);
    final current = await _find(productId);
    final now = _clock.nowUtc();
    final operationId = OperationId(_uuid.v4());
    final candidate = Product(
      id: current.id,
      name: draft.name.trim(),
      code: _optional(draft.code),
      unit: draft.unit,
      isActive: current.isActive,
      defaultSalePricePiastersPerKg: draft.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: draft.minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg: draft.referenceCostPricePiastersPerKg,
      notes: _optional(draft.notes),
      createdAt: current.createdAt,
      updatedAt: now.toLocal(),
    );
    final payload = ProductCatalogPayload.fromProduct(
      mutationKind: ProductCatalogMutationKind.update,
      remoteProductId: state.remoteProductId,
      product: candidate,
      legacyLocalId: productId == state.remoteProductId ? null : productId,
    );
    final envelope = _envelope(
      binding,
      operationId,
      payload,
      baseVersion: state.acknowledgedEntityVersion!,
      nowUtc: now,
    );
    final product = await _durableStore.enqueueWithMutation(
      envelope,
      () async {
        final updated =
            await _local.updateProduct(productId: productId, draft: draft);
        await _syncStore.setPending(
          state: state,
          operationId: operationId.value,
          nowUtc: now,
        );
        return updated;
      },
    );
    _triggerSync();
    return product;
  }

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    if (!_cloudModeEnabled) {
      return _local.setProductActive(
        productId: productId,
        isActive: isActive,
      );
    }
    final binding = await _requireOwnerBinding();
    final state = await _requireMutableState(productId, binding);
    final current = await _find(productId);
    final now = _clock.nowUtc();
    final operationId = OperationId(_uuid.v4());
    final candidate = current.copyWith(
      isActive: isActive,
      updatedAt: now.toLocal(),
    );
    final payload = ProductCatalogPayload.fromProduct(
      mutationKind: ProductCatalogMutationKind.setActive,
      remoteProductId: state.remoteProductId,
      product: candidate,
      legacyLocalId: productId == state.remoteProductId ? null : productId,
    );
    final envelope = _envelope(
      binding,
      operationId,
      payload,
      baseVersion: state.acknowledgedEntityVersion!,
      nowUtc: now,
    );
    final product = await _durableStore.enqueueWithMutation(
      envelope,
      () async {
        final updated = await _local.setProductActive(
          productId: productId,
          isActive: isActive,
        );
        await _syncStore.setPending(
          state: state,
          operationId: operationId.value,
          nowUtc: now,
        );
        return updated;
      },
    );
    _triggerSync();
    return product;
  }

  Future<void> adoptLegacyProduct(String localProductId) async {
    final binding = await _requireOwnerBinding();
    final checkpoint = await _durableStore.loadCheckpoint(
      binding.scope,
      productCatalogSourceAuthority,
      productCatalogStreamName,
    );
    if (checkpoint == null) {
      throw StateError('productCatalog.pullRequiredBeforeAdoption');
    }
    if (await _syncStore.loadByLocalId(localProductId) != null) {
      throw StateError('productCatalog.productAlreadyBound');
    }
    final product = await _find(localProductId);
    final now = _clock.nowUtc();
    final operationId = OperationId(_uuid.v4());
    final remoteId = _uuid.v4();
    final payload = ProductCatalogPayload.fromProduct(
      mutationKind: ProductCatalogMutationKind.create,
      remoteProductId: remoteId,
      legacyLocalId: localProductId,
      product: product,
    );
    await _durableStore.enqueueWithMutation(
      _envelope(binding, operationId, payload, baseVersion: null, nowUtc: now),
      () => _syncStore.createPending(
        localProductId: localProductId,
        businessId: binding.businessId.value,
        remoteProductId: remoteId,
        operationId: operationId.value,
        nowUtc: now,
      ),
    );
    _triggerSync();
  }

  @override
  Future<void> restoreProductsIntoEmpty(List<Product> products) =>
      _local.restoreProductsIntoEmpty(products);

  @override
  Future<void> clearForOwnerDataWipe() => _local.clearForOwnerDataWipe();

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _local.createTransactionSnapshot();

  Future<ProductCatalogScopeBinding> _requireOwnerBinding() async {
    final now = _clock.nowUtc();
    final context = _contexts.current;
    ProductCatalogScopeBinding? binding;
    if (context?.business != null &&
        context!.business!.scope is BusinessWide &&
        context.session.remoteAuthUserIdentity ==
            context.business!.memberAuthUserId) {
      binding = await _syncStore.bindVerified(context.business!, now);
    } else {
      final userId = _currentRemoteAuthUserId();
      if (userId != null) {
        binding = await _syncStore.loadActiveBindingForUser(userId);
      }
    }
    if (binding == null || !binding.canMutate) {
      throw StateError('productCatalog.ownerBindingRequired');
    }
    return binding;
  }

  Future<ProductCatalogSyncState> _requireMutableState(
    String productId,
    ProductCatalogScopeBinding binding,
  ) async {
    final state = await _syncStore.loadByLocalId(productId);
    if (state == null || state.businessId != binding.businessId.value) {
      throw StateError('productCatalog.explicitAdoptionRequired');
    }
    if (state.acknowledgedEntityVersion == null ||
        state.pendingOperationId != null ||
        state.projectionState != ProductCloudDisposition.acknowledged) {
      throw StateError('productCatalog.unresolvedMutation');
    }
    return state;
  }

  DurableOutboxEnvelope _envelope(
    ProductCatalogScopeBinding binding,
    OperationId operationId,
    ProductCatalogPayload payload, {
    required int? baseVersion,
    required DateTime nowUtc,
  }) {
    final context = _contexts.current;
    return DurableOutboxEnvelope(
      operationId: operationId,
      idempotencyKey: operationId.value,
      scope: binding.scope,
      actorAuthUserId: binding.authUserId,
      deviceId: _deviceIdentity,
      sessionId: context?.session.sessionId ?? SessionId(_uuid.v4()),
      capturedRole: binding.role,
      operationKind: payload.mutationKind.wireName,
      aggregateType: 'product',
      aggregateId: payload.remoteProductId,
      payloadSchemaVersion: productCatalogPayloadSchemaVersion,
      payloadJson: payload.canonicalPayloadJson,
      payloadFingerprint: payload.fingerprint,
      baseEntityVersion:
          baseVersion == null ? null : EntityVersion(baseVersion),
      occurredAtUtc: nowUtc,
    );
  }

  Future<Product> _find(String productId) async {
    final products = await _local.listProducts();
    return products.firstWhere(
      (product) => product.id == productId,
      orElse: () => throw StateError('Product was not found.'),
    );
  }

  void _triggerSync() {
    final trigger = _requestSync;
    if (trigger != null) unawaited(_triggerSyncSafely(trigger));
  }

  Future<void> _triggerSyncSafely(Future<void> Function() trigger) async {
    try {
      await trigger();
    } on Object {
      // The local commit and durable outbox are authoritative while offline.
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
