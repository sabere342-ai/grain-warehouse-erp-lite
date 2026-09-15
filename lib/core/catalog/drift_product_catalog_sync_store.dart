import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

final class ProductCatalogScopeBinding {
  const ProductCatalogScopeBinding({
    required this.businessId,
    required this.authUserId,
    required this.role,
    required this.verifiedAtUtc,
  });

  final BusinessId businessId;
  final RemoteAuthUserId authUserId;
  final String role;
  final DateTime verifiedAtUtc;
  bool get canMutate => role == 'owner';
  DurableScope get scope => DurableScope(
        businessId: businessId,
        kind: DurableScopeKind.businessWide,
      );
}

final class ProductCatalogSyncState {
  const ProductCatalogSyncState({
    required this.localProductId,
    required this.businessId,
    required this.remoteProductId,
    required this.projectionState,
    this.acknowledgedEntityVersion,
    this.acknowledgedPayloadJson,
    this.acknowledgedPayloadFingerprint,
    this.pendingOperationId,
  });

  final String localProductId;
  final String businessId;
  final String remoteProductId;
  final ProductCloudDisposition projectionState;
  final int? acknowledgedEntityVersion;
  final String? acknowledgedPayloadJson;
  final String? acknowledgedPayloadFingerprint;
  final String? pendingOperationId;
}

final class DriftProductCatalogSyncStore {
  const DriftProductCatalogSyncStore(this.database);

  final db.FoundationDatabase database;

  Future<ProductCatalogScopeBinding> bindVerified(
    BusinessContext context,
    DateTime verifiedAtUtc,
  ) =>
      database.inTransaction(() async {
        if (context.scope is! BusinessWide ||
            !const {'owner', 'employee', 'viewer'}.contains(context.role) ||
            !verifiedAtUtc.isUtc) {
          throw StateError('productCatalog.invalidVerifiedBinding');
        }
        final active =
            await (database.select(database.productCatalogScopeBindings)
                  ..where((row) => row.isActive.equals(true)))
                .getSingleOrNull();
        if (active != null && active.businessId != context.businessId.value) {
          throw StateError('productCatalog.secondBusinessRefused');
        }
        await database
            .into(database.productCatalogScopeBindings)
            .insertOnConflictUpdate(
              db.ProductCatalogScopeBindingsCompanion.insert(
                businessId: context.businessId.value,
                authUserId: context.memberAuthUserId.value,
                role: context.role,
                verifiedAtUtc: verifiedAtUtc,
                isActive: true,
              ),
            );
        return ProductCatalogScopeBinding(
          businessId: context.businessId,
          authUserId: context.memberAuthUserId,
          role: context.role,
          verifiedAtUtc: verifiedAtUtc,
        );
      });

  Future<ProductCatalogScopeBinding?> loadActiveBindingForUser(
    String authUserId,
  ) async {
    final row = await (database.select(database.productCatalogScopeBindings)
          ..where((table) =>
              table.isActive.equals(true) &
              table.authUserId.equals(authUserId)))
        .getSingleOrNull();
    return row == null
        ? null
        : ProductCatalogScopeBinding(
            businessId: BusinessId(row.businessId),
            authUserId: RemoteAuthUserId(row.authUserId),
            role: row.role,
            verifiedAtUtc: row.verifiedAtUtc.toUtc(),
          );
  }

  Future<ProductCatalogScopeBinding?> loadActiveBinding() async {
    final row = await (database.select(database.productCatalogScopeBindings)
          ..where((table) => table.isActive.equals(true)))
        .getSingleOrNull();
    return row == null
        ? null
        : ProductCatalogScopeBinding(
            businessId: BusinessId(row.businessId),
            authUserId: RemoteAuthUserId(row.authUserId),
            role: row.role,
            verifiedAtUtc: row.verifiedAtUtc.toUtc(),
          );
  }

  Future<ProductCatalogSyncState?> loadByLocalId(String localProductId) async {
    final row = await (database.select(database.productCatalogSyncStates)
          ..where((table) => table.localProductId.equals(localProductId)))
        .getSingleOrNull();
    return row == null ? null : _state(row);
  }

  Future<ProductCatalogSyncState?> loadByRemoteId(
    String businessId,
    String remoteProductId,
  ) async {
    final row = await (database.select(database.productCatalogSyncStates)
          ..where((table) =>
              table.businessId.equals(businessId) &
              table.remoteProductId.equals(remoteProductId)))
        .getSingleOrNull();
    return row == null ? null : _state(row);
  }

  Future<void> createPending({
    required String localProductId,
    required String businessId,
    required String remoteProductId,
    required String operationId,
    required DateTime nowUtc,
  }) async {
    final existing = await loadByLocalId(localProductId);
    if (existing != null) {
      throw StateError('productCatalog.productAlreadyBound');
    }
    await database.into(database.productCatalogSyncStates).insert(
          db.ProductCatalogSyncStatesCompanion.insert(
            localProductId: localProductId,
            businessId: businessId,
            remoteProductId: remoteProductId,
            pendingOperationId: Value(operationId),
            projectionState: ProductCloudDisposition.pending.name,
            updatedAtUtc: nowUtc,
          ),
        );
  }

  Future<void> setPending({
    required ProductCatalogSyncState state,
    required String operationId,
    required DateTime nowUtc,
  }) async {
    if (state.pendingOperationId != null ||
        state.projectionState == ProductCloudDisposition.attentionRequired ||
        state.projectionState == ProductCloudDisposition.tombstoned) {
      throw StateError('productCatalog.unresolvedMutation');
    }
    final affected = await (database.update(database.productCatalogSyncStates)
          ..where((row) =>
              row.localProductId.equals(state.localProductId) &
              row.pendingOperationId.isNull()))
        .write(
      db.ProductCatalogSyncStatesCompanion(
        pendingOperationId: Value(operationId),
        projectionState: Value(ProductCloudDisposition.pending.name),
        updatedAtUtc: Value(nowUtc),
      ),
    );
    if (affected != 1) throw StateError('productCatalog.unresolvedMutation');
  }

  Future<void> applyAcknowledgement(
    ProductCatalogRemoteChange change,
    String pendingOperationId,
    DateTime nowUtc,
  ) async {
    final state = await loadByRemoteId(
      (await loadActiveBinding())!.businessId.value,
      change.payload.remoteProductId,
    );
    if (state == null || state.pendingOperationId != pendingOperationId) {
      throw StateError('productCatalog.acknowledgedProjectionMismatch');
    }
    await _writeProduct(state.localProductId, change.payload, nowUtc);
    await _writeAcknowledgedState(
      state.localProductId,
      change,
      nowUtc,
      clearPending: true,
    );
  }

  Future<void> applyInbound(
    ProductCatalogRemoteChange change,
    String businessId,
    DateTime nowUtc,
  ) async {
    final state =
        await loadByRemoteId(businessId, change.payload.remoteProductId);
    if (state?.pendingOperationId != null) {
      throw StateError('productCatalog.pendingConflict');
    }
    if (state != null &&
        state.acknowledgedEntityVersion != null &&
        change.entityVersion.value < state.acknowledgedEntityVersion!) {
      return;
    }
    final localId = state?.localProductId ?? change.payload.remoteProductId;
    await _writeProduct(localId, change.payload, nowUtc);
    if (state == null) {
      await database.into(database.productCatalogSyncStates).insert(
            db.ProductCatalogSyncStatesCompanion.insert(
              localProductId: localId,
              businessId: businessId,
              remoteProductId: change.payload.remoteProductId,
              projectionState: change.deletionMetadata == null
                  ? ProductCloudDisposition.acknowledged.name
                  : ProductCloudDisposition.tombstoned.name,
              updatedAtUtc: nowUtc,
            ),
          );
    }
    await _writeAcknowledgedState(localId, change, nowUtc, clearPending: false);
  }

  Future<void> markAttention(String localProductId, DateTime nowUtc) async {
    await (database.update(database.productCatalogSyncStates)
          ..where((row) => row.localProductId.equals(localProductId)))
        .write(
      db.ProductCatalogSyncStatesCompanion(
        projectionState: Value(ProductCloudDisposition.attentionRequired.name),
        updatedAtUtc: Value(nowUtc),
      ),
    );
  }

  Future<void> acceptRemoteResolution({
    required String localProductId,
    required ProductCatalogRemoteChange change,
    required String businessId,
    required DateTime nowUtc,
  }) async {
    var state = await loadByLocalId(localProductId);
    if (state == null || state.businessId != businessId) {
      throw StateError('productCatalog.conflictProductMissing');
    }
    if (state.remoteProductId != change.payload.remoteProductId) {
      await rebindRemoteIdentity(
        state: state,
        remoteProductId: change.payload.remoteProductId,
        nowUtc: nowUtc,
      );
      state = await loadByLocalId(localProductId);
      if (state == null) throw const DurableLostRaceException();
    }
    await _writeProduct(state.localProductId, change.payload, nowUtc);
    await _writeAcknowledgedState(
      state.localProductId,
      change,
      nowUtc,
      clearPending: true,
    );
  }

  Future<void> rebindRemoteIdentity({
    required ProductCatalogSyncState state,
    required String remoteProductId,
    required DateTime nowUtc,
  }) async {
    if (state.remoteProductId == remoteProductId) return;
    final alreadyBound =
        await loadByRemoteId(state.businessId, remoteProductId);
    if (alreadyBound != null) {
      throw StateError('productCatalog.remoteProductAlreadyBound');
    }
    final affected = await (database.update(database.productCatalogSyncStates)
          ..where((row) =>
              row.localProductId.equals(state.localProductId) &
              row.businessId.equals(state.businessId) &
              row.remoteProductId.equals(state.remoteProductId)))
        .write(
      db.ProductCatalogSyncStatesCompanion(
        remoteProductId: Value(remoteProductId),
        updatedAtUtc: Value(nowUtc),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  Future<void> replaceConflictPending({
    required ProductCatalogSyncState state,
    required String expectedPendingOperationId,
    required String replacementOperationId,
    required DateTime nowUtc,
  }) async {
    final affected = await (database.update(database.productCatalogSyncStates)
          ..where((row) =>
              row.localProductId.equals(state.localProductId) &
              row.businessId.equals(state.businessId) &
              row.pendingOperationId.equals(expectedPendingOperationId) &
              row.projectionState.equals(
                ProductCloudDisposition.attentionRequired.name,
              )))
        .write(
      db.ProductCatalogSyncStatesCompanion(
        pendingOperationId: Value(replacementOperationId),
        projectionState: Value(ProductCloudDisposition.pending.name),
        updatedAtUtc: Value(nowUtc),
      ),
    );
    if (affected != 1) throw const DurableLostRaceException();
  }

  Future<void> _writeAcknowledgedState(
    String localProductId,
    ProductCatalogRemoteChange change,
    DateTime nowUtc, {
    required bool clearPending,
  }) async {
    final deletion = change.deletionMetadata;
    await (database.update(database.productCatalogSyncStates)
          ..where((row) => row.localProductId.equals(localProductId)))
        .write(
      db.ProductCatalogSyncStatesCompanion(
        acknowledgedEntityVersion: Value(change.entityVersion.value),
        acknowledgedPayloadJson: Value(change.payload.canonicalPayloadJson),
        acknowledgedPayloadFingerprint: Value(change.payload.fingerprint),
        acknowledgedServerModifiedAtUtc: Value(change.serverModifiedAtUtc),
        acknowledgedSourceOperationId: Value(change.sourceOperationId.value),
        acknowledgedActorAuthUserId: Value(change.actorAuthUserId.value),
        acknowledgedDeviceId: Value(change.deviceId.value),
        pendingOperationId:
            clearPending ? const Value(null) : const Value.absent(),
        projectionState: Value(deletion == null
            ? ProductCloudDisposition.acknowledged.name
            : ProductCloudDisposition.tombstoned.name),
        tombstoneVersion: Value(deletion?.deletionVersion.value),
        deletedAtUtc: Value(deletion?.deletedAtUtc),
        deletedByAuthUserId: Value(deletion?.deletedByAuthUserId.value),
        deletedByDeviceId: Value(deletion?.deletedByDeviceId.value),
        deletionSourceOperationId: Value(deletion?.sourceOperationId.value),
        updatedAtUtc: Value(nowUtc),
      ),
    );
  }

  Future<void> _writeProduct(
    String localId,
    ProductCatalogPayload payload,
    DateTime nowUtc,
  ) async {
    final current = await (database.select(database.products)
          ..where((row) => row.id.equals(localId)))
        .getSingleOrNull();
    final companion = db.ProductsCompanion(
      id: Value(localId),
      name: Value(payload.name),
      normalizedName: Value(payload.name.trim().toLowerCase()),
      code: Value(payload.code),
      normalizedCode: Value(payload.code?.trim().toLowerCase()),
      unit: Value(payload.unit.wireName),
      isActive: Value(payload.isActive),
      defaultSalePricePiastersPerKg:
          Value(payload.defaultSalePricePiastersPerKg),
      minimumSalePricePiastersPerKg:
          Value(payload.minimumSalePricePiastersPerKg),
      referenceCostPricePiastersPerKg:
          Value(payload.referenceCostPricePiastersPerKg),
      notes: Value(payload.notes),
      createdAt: Value(current?.createdAt ?? nowUtc.toLocal()),
      updatedAt: Value(nowUtc.toLocal()),
    );
    if (current == null) {
      await database.into(database.products).insert(companion);
    } else {
      await (database.update(database.products)
            ..where((row) => row.id.equals(localId)))
          .write(companion);
    }
  }

  ProductCatalogSyncState _state(db.ProductCatalogSyncStateRow row) =>
      ProductCatalogSyncState(
        localProductId: row.localProductId,
        businessId: row.businessId,
        remoteProductId: row.remoteProductId,
        projectionState:
            ProductCloudDisposition.values.byName(row.projectionState),
        acknowledgedEntityVersion: row.acknowledgedEntityVersion,
        acknowledgedPayloadJson: row.acknowledgedPayloadJson,
        acknowledgedPayloadFingerprint: row.acknowledgedPayloadFingerprint,
        pendingOperationId: row.pendingOperationId,
      );
}
