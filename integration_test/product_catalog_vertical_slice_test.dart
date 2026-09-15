import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/catalog_sync/product_catalog_sync_coordinator.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
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
import 'package:grain_warehouse_erp_lite/infrastructure/supabase/supabase_product_catalog_gateways.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _businessId = '51000000-0000-4000-8000-000000000001';
const _email = 'catalog-integration@example.test';
const _password = 'Catalog-Test-Only-2026!';
const _firstDeviceId = '52000000-0000-4000-8000-000000000001';
const _secondDeviceId = '52000000-0000-4000-8000-000000000002';
const _tombstoneOperationId = '53000000-0000-4000-8000-000000000001';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

  test(
    'two file-backed app databases converge through isolated local Supabase',
    () async {
      final config = await _LocalSupabaseConfig.discover();
      final fixture = _CatalogServerFixture(config.databaseUrl);
      await fixture.verifyTarget();
      await fixture.clear();

      const authOptions = AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      );
      final firstClient = SupabaseClient(
        config.apiUrl,
        config.publishableKey,
        authOptions: authOptions,
      );
      final secondClient = SupabaseClient(
        config.apiUrl,
        config.publishableKey,
        authOptions: authOptions,
      );
      final directory =
          await Directory.systemTemp.createTemp('catalog-supabase-e2e-');
      final firstFile = File(
        '${directory.path}${Platform.pathSeparator}first.sqlite3',
      );
      final secondFile = File(
        '${directory.path}${Platform.pathSeparator}second.sqlite3',
      );
      _RealCatalogHarness? first;
      _RealCatalogHarness? second;
      try {
        final registration = await firstClient.auth.signUp(
          email: _email,
          password: _password,
        );
        final userId = registration.user?.id;
        expect(userId, isNotNull);
        expect(registration.session, isNotNull);
        await fixture.grantOwner(userId!);
        final secondSession = await secondClient.auth.signInWithPassword(
          email: _email,
          password: _password,
        );
        expect(secondSession.session, isNotNull);

        first = await _RealCatalogHarness.open(
          file: firstFile,
          client: firstClient,
          userId: userId,
          deviceId: _firstDeviceId,
        );
        second = await _RealCatalogHarness.open(
          file: secondFile,
          client: secondClient,
          userId: userId,
          deviceId: _secondDeviceId,
        );

        final product = await first.repository.createProduct(
          const ProductDraft(
            name: 'اختبار تكامل حقيقي',
            code: 'E2E-REAL-1',
            unit: GrainUnit.kilogram,
          ),
        );
        expect(await first.pendingCount(), 1);
        await first.coordinator.synchronizeOnce();
        expect(await first.pendingCount(), 0);
        await second.coordinator.synchronizeOnce();
        expect((await second.reads()).single.id, product.id);

        await first.repository.updateProduct(
          productId: product.id,
          draft: const ProductDraft(
            name: 'تعديل الجهاز الأول',
            code: 'E2E-REAL-1',
            unit: GrainUnit.kilogram,
          ),
        );
        await second.repository.updateProduct(
          productId: product.id,
          draft: const ProductDraft(
            name: 'تعديل الجهاز الثاني',
            code: 'E2E-REAL-1',
            unit: GrainUnit.kilogram,
          ),
        );
        await first.coordinator.synchronizeOnce();
        await second.coordinator.synchronizeOnce();
        expect(
          await second.coordinator.listUnresolvedForProduct(product.id),
          hasLength(1),
        );

        await second.close();
        second = await _RealCatalogHarness.open(
          file: secondFile,
          client: secondClient,
          userId: userId,
          deviceId: _secondDeviceId,
        );
        final conflict =
            (await second.coordinator.listUnresolvedForProduct(product.id))
                .single;
        await second.coordinator.acceptServer(
          localProductId: product.id,
          conflictId: conflict.evidence.conflictId,
          expectedRecordVersion: conflict.recordVersion,
        );
        expect((await second.reads()).single.name, 'تعديل الجهاز الأول');

        await fixture.tombstone(product.id, userId);
        await first.coordinator.synchronizeOnce();
        await second.coordinator.synchronizeOnce();
        expect(await first.reads(), isEmpty);
        expect(await second.reads(), isEmpty);

        await second.close();
        second = await _RealCatalogHarness.open(
          file: secondFile,
          client: secondClient,
          userId: userId,
          deviceId: _secondDeviceId,
        );
        expect(await second.reads(), isEmpty);
        final state = await second.syncStore.loadByLocalId(product.id);
        expect(state?.projectionState.name, 'tombstoned');
        expect(state?.acknowledgedEntityVersion, 3);
      } finally {
        await first?.close();
        await second?.close();
        await firstClient.dispose();
        await secondClient.dispose();
        await fixture.clear();
        if (directory.existsSync()) await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

final class _RealCatalogHarness {
  _RealCatalogHarness._({
    required this.database,
    required this.syncStore,
    required this.repository,
    required this.coordinator,
  });

  static Future<_RealCatalogHarness> open({
    required File file,
    required SupabaseClient client,
    required String userId,
    required String deviceId,
  }) async {
    final database = openDatabaseFile(file);
    const clock = SystemApplicationClock();
    final identity = DeviceId(deviceId);
    final contexts = MutableExecutionContextProvider()
      ..replace(
        ExecutionContext.verifiedBusiness(
          session: SessionContext.verifiedRemote(
            sessionId: SessionId(const Uuid().v4()),
            remoteAuthUserId: RemoteAuthUserId(userId),
          ),
          business: BusinessContext.verifiedMembership(
            businessId: BusinessId(_businessId),
            memberAuthUserId: RemoteAuthUserId(userId),
            role: 'owner',
            scope: const BusinessWide(),
          ),
          deviceIdentity: identity,
        ),
      );
    final syncStore = DriftProductCatalogSyncStore(database);
    await syncStore.bindVerified(contexts.current!.business!, clock.nowUtc());
    final durableStore = DriftDurableSyncStore(database, clock: clock);
    final coordinator = ProductCatalogSyncCoordinator(
      durableStore: durableStore,
      productStore: syncStore,
      pushGateway: SupabaseProductCatalogPushGateway(client),
      pullGateway: SupabaseProductCatalogPullGateway(client),
      executionContexts: contexts,
      clock: clock,
    );
    return _RealCatalogHarness._(
      database: database,
      syncStore: syncStore,
      repository: CloudHybridProductRepository(
        localRepository: DriftProductRepository(database),
        syncStore: syncStore,
        durableStore: durableStore,
        executionContextProvider: contexts,
        clock: clock,
        deviceIdentity: identity,
        cloudModeEnabled: true,
        currentRemoteAuthUserId: () => client.auth.currentUser?.id,
      ),
      coordinator: coordinator,
    );
  }

  final FoundationDatabase database;
  final DriftProductCatalogSyncStore syncStore;
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

final class _LocalSupabaseConfig {
  const _LocalSupabaseConfig({
    required this.apiUrl,
    required this.publishableKey,
    required this.databaseUrl,
  });

  static Future<_LocalSupabaseConfig> discover() async {
    final appData = Platform.environment['APPDATA'];
    final cli = appData == null
        ? null
        : File('$appData${Platform.pathSeparator}npm'
            '${Platform.pathSeparator}supabase.ps1');
    if (cli == null || !cli.existsSync()) {
      throw StateError('The local Supabase CLI is unavailable.');
    }
    final result = await Process.run(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        cli.path,
        'status',
        '-o',
        'env',
      ],
      workingDirectory: Directory.current.path,
      environment: <String, String>{
        ...Platform.environment,
        'SUPABASE_TELEMETRY_DISABLED': 'true',
      },
    );
    if (result.exitCode != 0) {
      throw StateError('The isolated local Supabase stack is unavailable.');
    }
    final values = <String, String>{};
    for (final line in (result.stdout as String).split(RegExp(r'\r?\n'))) {
      final match = RegExp(r'^([A-Z][A-Z0-9_]*)="?(.*?)"?$').firstMatch(line);
      if (match != null) values[match.group(1)!] = match.group(2)!;
    }
    final apiUrl = values['API_URL'];
    final publishableKey = values['PUBLISHABLE_KEY'] ?? values['ANON_KEY'];
    final databaseUrl = values['DB_URL'];
    final api = apiUrl == null ? null : Uri.tryParse(apiUrl);
    final database = databaseUrl == null ? null : Uri.tryParse(databaseUrl);
    if (api == null ||
        api.host != '127.0.0.1' ||
        api.port != 55321 ||
        database == null ||
        database.host != '127.0.0.1' ||
        database.port != 55322 ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      throw StateError('Supabase is not the isolated Grain test stack.');
    }
    return _LocalSupabaseConfig(
      apiUrl: apiUrl!,
      publishableKey: publishableKey,
      databaseUrl: databaseUrl!,
    );
  }

  final String apiUrl;
  final String publishableKey;
  final String databaseUrl;
}

final class _CatalogServerFixture {
  const _CatalogServerFixture(this._databaseUrl);

  final String _databaseUrl;

  Future<void> verifyTarget() async {
    final marker = await _query('''
select case
  when to_regclass('public.product_catalog_changes') is not null
   and to_regprocedure(
     'public.apply_product_catalog_operation_v1(text,text,text,text,text,bigint,jsonb,text)'
   ) is not null
  then 'grain-product-catalog-v1'
  else 'wrong-target'
end;
''');
    if (marker.trim() != 'grain-product-catalog-v1') {
      throw StateError('The database is not the Grain catalog test target.');
    }
  }

  Future<void> clear() => _execute('''
begin;
delete from public.product_catalog_changes
where business_id = '$_businessId'::uuid;
delete from private.product_catalog_operation_receipts
where business_id = '$_businessId'::uuid;
delete from public.products where business_id = '$_businessId'::uuid;
delete from public.business_memberships
where business_id = '$_businessId'::uuid;
delete from public.businesses where id = '$_businessId'::uuid;
delete from auth.users where email = '$_email';
commit;
''');

  Future<void> grantOwner(String userId) async {
    if (!Uuid.isValidUUID(fromString: userId)) {
      throw ArgumentError.value(userId, 'userId', 'UUID required.');
    }
    await _execute('''
begin;
insert into public.businesses (id, name)
values ('$_businessId'::uuid, 'Catalog integration fixture');
insert into public.business_memberships
  (business_id, auth_user_id, role, is_active)
values ('$_businessId'::uuid, '$userId'::uuid, 'owner', true);
commit;
''');
  }

  Future<void> tombstone(String productId, String userId) async {
    if (!Uuid.isValidUUID(fromString: productId) ||
        !Uuid.isValidUUID(fromString: userId)) {
      throw ArgumentError('Tombstone fixture IDs must be UUIDs.');
    }
    await _execute('''
with previous as (
  select product.id, product.business_id, product.entity_version,
         change.payload
  from public.products product
  join lateral (
    select item.payload
    from public.product_catalog_changes item
    where item.business_id = product.business_id
      and item.product_id = product.id
    order by item.change_cursor desc
    limit 1
  ) change on true
  where product.business_id = '$_businessId'::uuid
    and product.id = '$productId'::uuid
    and not product.is_deleted
), tombstoned as (
  update public.products product set
    is_active = false,
    is_deleted = true,
    entity_version = previous.entity_version + 1,
    server_modified_at_utc = clock_timestamp(),
    actor_auth_user_id = '$userId'::uuid,
    device_id = '$_secondDeviceId'::uuid,
    source_operation_id = '$_tombstoneOperationId'::uuid,
    deletion_version = previous.entity_version + 1,
    deleted_at_utc = clock_timestamp(),
    deleted_by_auth_user_id = '$userId'::uuid,
    deleted_by_device_id = '$_secondDeviceId'::uuid,
    deletion_source_operation_id = '$_tombstoneOperationId'::uuid
  from previous
  where product.id = previous.id
    and product.business_id = previous.business_id
  returning product.*, previous.payload as prior_payload
), materialized as (
  select tombstoned.*,
         jsonb_set(
           jsonb_set(
             tombstoned.prior_payload,
             '{mutationKind}',
             to_jsonb('product.setActive.v1'::text)
           ),
           '{isActive}',
           'false'::jsonb
         ) as next_payload
  from tombstoned
)
insert into public.product_catalog_changes (
  business_id, product_id, entity_version, operation_kind, payload,
  payload_fingerprint, source_operation_id, actor_auth_user_id,
  device_id, server_modified_at_utc, is_deleted, deletion_metadata
)
select
  business_id, id, entity_version, 'product.setActive.v1', next_payload,
  encode(
    extensions.digest(
      convert_to(private.canonical_jsonb_text(next_payload), 'UTF8'),
      'sha256'
    ),
    'hex'
  ),
  '$_tombstoneOperationId'::uuid, actor_auth_user_id, device_id,
  server_modified_at_utc, true,
  jsonb_build_object(
    'deletionVersion', entity_version,
    'deletedAtUtc', to_char(
      deleted_at_utc at time zone 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
    ),
    'deletedByAuthUserId', deleted_by_auth_user_id::text,
    'deletedByDeviceId', deleted_by_device_id::text,
    'sourceOperationId', deletion_source_operation_id::text
  )
from materialized;
''');
  }

  Future<String> _query(String sql) async {
    final result = await _runPsql(sql);
    return result.stdout as String;
  }

  Future<void> _execute(String sql) async {
    await _runPsql(sql);
  }

  Future<ProcessResult> _runPsql(String sql) async {
    final uri = Uri.parse(_databaseUrl);
    final credentials = uri.userInfo.split(':');
    if (uri.host != '127.0.0.1' || uri.port != 55322) {
      throw StateError('Refusing a non-isolated PostgreSQL target.');
    }
    final psql = _findPsql();
    final result = await Process.run(
      psql,
      <String>[
        '--host=${uri.host}',
        '--port=${uri.port}',
        '--username=${Uri.decodeComponent(credentials.first)}',
        '--dbname=${uri.pathSegments.single}',
        '--no-psqlrc',
        '--quiet',
        '--tuples-only',
        '--no-align',
        '--set=ON_ERROR_STOP=1',
        '--command=$sql',
      ],
      environment: <String, String>{
        ...Platform.environment,
        if (credentials.length == 2)
          'PGPASSWORD': Uri.decodeComponent(credentials.last),
      },
    );
    if (result.exitCode != 0) {
      throw StateError('Grain PostgreSQL integration fixture failed.');
    }
    return result;
  }

  String _findPsql() {
    final programFiles = Platform.environment['ProgramFiles'];
    if (programFiles != null) {
      for (final version in const ['18', '17', '16', '15']) {
        final candidate = File(
          '$programFiles${Platform.pathSeparator}PostgreSQL'
          '${Platform.pathSeparator}$version${Platform.pathSeparator}bin'
          '${Platform.pathSeparator}psql.exe',
        );
        if (candidate.existsSync()) return candidate.path;
      }
    }
    throw StateError('The local PostgreSQL client is unavailable.');
  }
}
