import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_contracts.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/cloud_hybrid_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const _businessId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';

void main() {
  test(
    'failed background sync preserves the local commit and durable outbox',
    () async {
      final syncAttempted = Completer<void>();
      final harness = await _Harness.open(
        _FakeProductCloud(),
        deviceSeed: '8',
        requestSync: () async {
          syncAttempted.complete();
          throw StateError('offline');
        },
      );
      addTearDown(harness.close);

      final product = await harness.repository.createProduct(
        const ProductDraft(name: 'محصول محلي', unit: GrainUnit.kilogram),
      );
      await syncAttempted.future;
      await Future<void>.delayed(Duration.zero);

      expect((await harness.local.listProducts()).single.id, product.id);
      expect(
        await harness.database
            .select(harness.database.durableOutboxOperations)
            .get(),
        hasLength(1),
      );
      expect(
        (await harness.syncStore.loadByLocalId(product.id))?.pendingOperationId,
        isNotNull,
      );
    },
  );

  test('v18 to v19 is additive and preserves legacy products', () async {
    final directory = await Directory.systemTemp.createTemp('catalog-v18-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    final local = DriftProductRepository(database);
    final product = await local.createProduct(
      const ProductDraft(name: 'شعير', unit: GrainUnit.kilogram),
    );
    await database.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE product_catalog_sync_states');
    legacy.execute('DROP TABLE product_catalog_scope_bindings');
    legacy.execute('PRAGMA user_version = 18');
    legacy.dispose();

    database = openDatabaseFile(file);
    expect(database.schemaVersion, 19);
    expect((await DriftProductRepository(database).listProducts()).single.id,
        product.id);
    expect(await database.select(database.productCatalogSyncStates).get(),
        isEmpty);
    await database.close();
  });

  test('V1 payload canonicalizes text and rejects unknown fields', () {
    final payload = ProductCatalogPayload(
      mutationKind: ProductCatalogMutationKind.create,
      remoteProductId: '33333333-3333-4333-8333-333333333333',
      name: '  قمح  ',
      code: '  W-1 ',
      unit: GrainUnit.kilogram,
      isActive: true,
    );
    expect(payload.name, 'قمح');
    expect(payload.code, 'W-1');
    expect(payload.fingerprint, hasLength(64));
    final decoded = ProductCatalogPayload.decode(payload.canonicalPayloadJson);
    expect(decoded.canonicalPayloadJson, payload.canonicalPayloadJson);
    final invalid = Map<String, Object?>.from(payload.toJson())
      ..['unexpected'] = true;
    expect(
      () => ProductCatalogPayload.fromJson(invalid),
      throwsFormatException,
    );
  });

  test('no-cloud mode preserves local behavior and creates no sync evidence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final local = DriftProductRepository(database);
    final clock = _FixedClock();
    final contexts = MutableExecutionContextProvider();
    final repository = CloudHybridProductRepository(
      localRepository: local,
      syncStore: DriftProductCatalogSyncStore(database),
      durableStore: DriftDurableSyncStore(database, clock: clock),
      executionContextProvider: contexts,
      clock: clock,
      deviceIdentity: DeviceId('99999999-9999-4999-8999-000000000009'),
      cloudModeEnabled: false,
      currentRemoteAuthUserId: () => null,
    );
    final product = await repository.createProduct(
      const ProductDraft(name: 'فول', unit: GrainUnit.kilogram),
    );
    expect(product.id, startsWith('prd-'));
    expect(await database.select(database.productCatalogSyncStates).get(),
        isEmpty);
    expect(
        await database.select(database.durableOutboxOperations).get(), isEmpty);
  });

  test(
      'two isolated SQLite catalogs converge, conflict, resolve, and tombstone',
      () async {
    final remote = _FakeProductCloud();
    final first = await _Harness.open(remote, deviceSeed: '4');
    final second = await _Harness.open(remote, deviceSeed: '5');
    addTearDown(first.close);
    addTearDown(second.close);

    final created = await first.repository.createProduct(
      const ProductDraft(name: 'قمح', unit: GrainUnit.kilogram),
    );
    expect(await first.pendingCount(), 1);
    expect(
      () => first.repository.updateProduct(
        productId: created.id,
        draft: const ProductDraft(
          name: 'تعديل سابق لأوانه',
          unit: GrainUnit.kilogram,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await first.coordinator.synchronizeOnce();
    expect(await first.pendingCount(), 0);
    expect((await first.reads()).single.cloudDisposition,
        ProductCloudDisposition.acknowledged);

    await second.coordinator.synchronizeOnce();
    expect((await second.reads()).single.id, created.id);

    await first.repository.updateProduct(
      productId: created.id,
      draft: const ProductDraft(name: 'قمح ممتاز', unit: GrainUnit.kilogram),
    );
    await second.repository.updateProduct(
      productId: created.id,
      draft: const ProductDraft(name: 'قمح محلي', unit: GrainUnit.kilogram),
    );
    await first.coordinator.synchronizeOnce();
    await second.coordinator.synchronizeOnce();
    expect((await second.reads()).single.cloudDisposition,
        ProductCloudDisposition.attentionRequired);
    final firstConflict =
        (await second.coordinator.listUnresolvedForProduct(created.id)).single;
    await second.coordinator.acceptServer(
      localProductId: created.id,
      conflictId: firstConflict.evidence.conflictId,
      expectedRecordVersion: firstConflict.recordVersion,
    );
    expect((await second.reads()).single.name, 'قمح ممتاز');

    await first.coordinator.synchronizeOnce();
    await first.repository.updateProduct(
      productId: created.id,
      draft: const ProductDraft(name: 'قمح خادم', unit: GrainUnit.kilogram),
    );
    await second.repository.updateProduct(
      productId: created.id,
      draft: const ProductDraft(name: 'قمح جهاز', unit: GrainUnit.kilogram),
    );
    await first.coordinator.synchronizeOnce();
    await second.coordinator.synchronizeOnce();
    final secondConflict =
        (await second.coordinator.listUnresolvedForProduct(created.id)).single;
    await second.coordinator.resubmitLocal(
      localProductId: created.id,
      conflictId: secondConflict.evidence.conflictId,
      expectedRecordVersion: secondConflict.recordVersion,
    );
    await second.coordinator.synchronizeOnce();
    expect((await second.reads()).single.name, 'قمح جهاز');
    expect(
        await second.coordinator.listUnresolvedForProduct(created.id), isEmpty);

    remote.tombstone(created.id);
    await first.coordinator.synchronizeOnce();
    expect(await first.reads(), isEmpty);
  });

  test('legacy adoption is explicit and requires a successful pull', () async {
    final remote = _FakeProductCloud();
    final harness = await _Harness.open(remote, deviceSeed: '6');
    addTearDown(harness.close);
    final local = await harness.local.createProduct(
      const ProductDraft(name: 'ذرة', unit: GrainUnit.ton),
    );
    expect(
      () => harness.repository.adoptLegacyProduct(local.id),
      throwsA(isA<StateError>()),
    );
    await harness.coordinator.synchronizeOnce();
    await harness.repository.adoptLegacyProduct(local.id);
    final state = await harness.syncStore.loadByLocalId(local.id);
    expect(state?.pendingOperationId, isNotNull);
    expect(state?.remoteProductId, isNot(local.id));
  });

  test('legacy natural-key conflicts support both explicit resolutions',
      () async {
    final acceptRemote = _FakeProductCloud()
      ..seed(
        remoteProductId: '31000000-0000-4000-8000-000000000021',
        sourceOperationId: '41000000-0000-4000-8000-000000000021',
        name: 'عدس مشترك',
      );
    final acceptHarness = await _Harness.open(acceptRemote, deviceSeed: '21');
    addTearDown(acceptHarness.close);
    final acceptedLocal = await acceptHarness.local.createProduct(
      const ProductDraft(name: 'عدس مشترك', unit: GrainUnit.kilogram),
    );
    await acceptHarness.coordinator.synchronizeOnce();
    await acceptHarness.repository.adoptLegacyProduct(acceptedLocal.id);
    await acceptHarness.coordinator.synchronizeOnce();
    final acceptConflict = (await acceptHarness.coordinator
            .listUnresolvedForProduct(acceptedLocal.id))
        .single;
    expect(
      acceptConflict.evidence.classification,
      DurableConflictClassification.duplicateNaturalKey,
    );
    await acceptHarness.coordinator.acceptServer(
      localProductId: acceptedLocal.id,
      conflictId: acceptConflict.evidence.conflictId,
      expectedRecordVersion: acceptConflict.recordVersion,
    );
    final acceptedState =
        await acceptHarness.syncStore.loadByLocalId(acceptedLocal.id);
    expect(
        acceptedState?.remoteProductId, '31000000-0000-4000-8000-000000000021');
    expect(acceptedState?.pendingOperationId, isNull);
    expect((await acceptHarness.reads()).single.id, acceptedLocal.id);

    final keepLocalRemote = _FakeProductCloud()
      ..seed(
        remoteProductId: '31000000-0000-4000-8000-000000000022',
        sourceOperationId: '41000000-0000-4000-8000-000000000022',
        name: 'فاصوليا مشتركة',
      );
    final keepHarness = await _Harness.open(keepLocalRemote, deviceSeed: '22');
    addTearDown(keepHarness.close);
    final keptLocal = await keepHarness.local.createProduct(
      const ProductDraft(
        name: 'فاصوليا مشتركة',
        unit: GrainUnit.ton,
        notes: 'المرشح المحلي',
      ),
    );
    await keepHarness.coordinator.synchronizeOnce();
    await keepHarness.repository.adoptLegacyProduct(keptLocal.id);
    await keepHarness.coordinator.synchronizeOnce();
    final keepConflict =
        (await keepHarness.coordinator.listUnresolvedForProduct(keptLocal.id))
            .single;
    await keepHarness.coordinator.resubmitLocal(
      localProductId: keptLocal.id,
      conflictId: keepConflict.evidence.conflictId,
      expectedRecordVersion: keepConflict.recordVersion,
    );
    await keepHarness.coordinator.synchronizeOnce();
    expect(await keepHarness.coordinator.listUnresolvedForProduct(keptLocal.id),
        isEmpty);
    final keptState = await keepHarness.syncStore.loadByLocalId(keptLocal.id);
    expect(keptState?.remoteProductId, '31000000-0000-4000-8000-000000000022');
    expect((await keepHarness.reads()).single.notes, 'المرشح المحلي');
  });
}

final class _Harness {
  _Harness._({
    required this.database,
    required this.local,
    required this.syncStore,
    required this.durableStore,
    required this.repository,
    required this.coordinator,
  });

  static Future<_Harness> open(
    _FakeProductCloud remote, {
    required String deviceSeed,
    Future<void> Function()? requestSync,
  }) async {
    final database = openInMemoryTestDatabase();
    final clock = _FixedClock();
    final contexts = MutableExecutionContextProvider()
      ..replace(_context(deviceSeed));
    final local = DriftProductRepository(database);
    final syncStore = DriftProductCatalogSyncStore(database);
    final durableStore = DriftDurableSyncStore(database, clock: clock);
    await syncStore.bindVerified(contexts.current!.business!, clock.nowUtc());
    final coordinator = ProductCatalogSyncCoordinator(
      durableStore: durableStore,
      productStore: syncStore,
      pushGateway: remote,
      pullGateway: remote,
      executionContexts: contexts,
      clock: clock,
    );
    final repository = CloudHybridProductRepository(
      localRepository: local,
      syncStore: syncStore,
      durableStore: durableStore,
      executionContextProvider: contexts,
      clock: clock,
      deviceIdentity: contexts.current!.deviceIdentity,
      cloudModeEnabled: true,
      currentRemoteAuthUserId: () => _ownerId,
      requestSync: requestSync,
    );
    return _Harness._(
      database: database,
      local: local,
      syncStore: syncStore,
      durableStore: durableStore,
      repository: repository,
      coordinator: coordinator,
    );
  }

  final FoundationDatabase database;
  final DriftProductRepository local;
  final DriftProductCatalogSyncStore syncStore;
  final DriftDurableSyncStore durableStore;
  final CloudHybridProductRepository repository;
  final ProductCatalogSyncCoordinator coordinator;

  Future<List<dynamic>> reads() => DriftProductCatalogReadRepository(database)
      .listProductCatalog(includeInactive: true);

  Future<int> pendingCount() async =>
      (await database.select(database.productCatalogSyncStates).get())
          .where((row) => row.pendingOperationId != null)
          .length;

  Future<void> close() => database.close();
}

final class _FakeProductCloud
    implements ProductCatalogPushGateway, ProductCatalogPullGateway {
  final Map<String, ProductCatalogRemoteChange> _current = {};
  final List<ProductCatalogRemoteChange> _changes = [];

  @override
  Future<ProductCatalogPushOutcome> push(
      ProductCatalogPushRequest request) async {
    final envelope = request.operation.envelope;
    final payload = ProductCatalogPayload.decode(envelope.payloadJson);
    final current = _current[payload.remoteProductId];
    if (payload.mutationKind == ProductCatalogMutationKind.create) {
      ProductCatalogRemoteChange? naturalKeyCollision;
      for (final candidate in _current.values) {
        final sameName =
            candidate.payload.name.toLowerCase() == payload.name.toLowerCase();
        final sameCode = payload.code != null &&
            candidate.payload.code?.toLowerCase() ==
                payload.code!.toLowerCase();
        if (sameName || sameCode) {
          naturalKeyCollision = candidate;
          break;
        }
      }
      if (current != null || naturalKeyCollision != null) {
        return ProductCatalogPushVersionConflict(
          'duplicateNaturalKey',
          current ?? naturalKeyCollision!,
        );
      }
    } else if (current == null ||
        envelope.baseEntityVersion?.value != current.entityVersion.value) {
      if (current == null) {
        return const ProductCatalogPushPermanentFailure(
          DurableErrorClass.validation,
          'product.notFound',
        );
      }
      return ProductCatalogPushVersionConflict('versionMismatch', current);
    }
    final change = ProductCatalogRemoteChange(
      payload: payload,
      entityVersion: EntityVersion((current?.entityVersion.value ?? 0) + 1),
      sourceOperationId: envelope.operationId,
      actorAuthUserId: envelope.actorAuthUserId,
      deviceId: envelope.deviceId,
      serverModifiedAtUtc: DateTime.utc(2026, 9, 12, 12),
      changeCursor: _changes.length + 1,
    );
    _current[payload.remoteProductId] = change;
    _changes.add(change);
    return ProductCatalogPushAccepted(change);
  }

  @override
  Future<List<ProductCatalogRemoteChange>> pull({
    required DurableScope scope,
    required int afterCursor,
    required int limit,
  }) async =>
      _changes
          .where((change) => change.changeCursor > afterCursor)
          .take(limit)
          .toList(growable: false);

  void seed({
    required String remoteProductId,
    required String sourceOperationId,
    required String name,
  }) {
    final payload = ProductCatalogPayload(
      mutationKind: ProductCatalogMutationKind.create,
      remoteProductId: remoteProductId,
      name: name,
      unit: GrainUnit.kilogram,
      isActive: true,
    );
    final change = ProductCatalogRemoteChange(
      payload: payload,
      entityVersion: EntityVersion.initial,
      sourceOperationId: OperationId(sourceOperationId),
      actorAuthUserId: RemoteAuthUserId(_ownerId),
      deviceId: DeviceId('99999999-9999-4999-8999-000000000099'),
      serverModifiedAtUtc: DateTime.utc(2026, 9, 12, 11),
      changeCursor: _changes.length + 1,
    );
    _current[remoteProductId] = change;
    _changes.add(change);
  }

  void tombstone(String remoteProductId) {
    final current = _current[remoteProductId]!;
    final version = EntityVersion(current.entityVersion.value + 1);
    final operationId = OperationId(
      '77777777-7777-4777-8777-${version.value.toString().padLeft(12, '0')}',
    );
    final change = ProductCatalogRemoteChange(
      payload: current.payload,
      entityVersion: version,
      sourceOperationId: operationId,
      actorAuthUserId: current.actorAuthUserId,
      deviceId: current.deviceId,
      serverModifiedAtUtc: DateTime.utc(2026, 9, 12, 13),
      changeCursor: _changes.length + 1,
      deletionMetadata: DeletionMetadata(
        deletionVersion: version,
        deletedAtUtc: DateTime.utc(2026, 9, 12, 13),
        deletedByAuthUserId: current.actorAuthUserId,
        deletedByDeviceId: current.deviceId,
        sourceOperationId: operationId,
      ),
    );
    _current[remoteProductId] = change;
    _changes.add(change);
  }
}

ExecutionContext _context(String deviceSeed) =>
    ExecutionContext.verifiedBusiness(
      session: SessionContext.verifiedRemote(
        sessionId: SessionId(
          '88888888-8888-4888-8888-${deviceSeed.padLeft(12, '0')}',
        ),
        remoteAuthUserId: RemoteAuthUserId(_ownerId),
      ),
      business: BusinessContext.verifiedMembership(
        businessId: BusinessId(_businessId),
        memberAuthUserId: RemoteAuthUserId(_ownerId),
        role: 'owner',
        scope: const BusinessWide(),
      ),
      deviceIdentity: DeviceId(
        '99999999-9999-4999-8999-${deviceSeed.padLeft(12, '0')}',
      ),
    );

final class _FixedClock implements ApplicationClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 12, 12);
}
