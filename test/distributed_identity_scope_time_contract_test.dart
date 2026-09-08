import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/device_identity_store.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/infrastructure/local/file_device_identity_store.dart';
import 'package:path/path.dart' as path;

void main() {
  group('distributed identity and explicit scope', () {
    test('UUID identities canonicalize and keep distinct types', () {
      expect(BusinessId(' $businessIdUpper ').value, businessId);
      expect(WarehouseId(warehouseId).value, warehouseId);
      expect(DeviceId(deviceId).value, deviceId);
      expect(SessionId(sessionId).value, sessionId);
      expect(RemoteAuthUserId(actorId).value, actorId);
      expect(OperationId(operationId).value, operationId);
      expect(BusinessId(businessId), isNot(equals(WarehouseId(businessId))));

      expect(() => BusinessId(''), throwsArgumentError);
      expect(() => WarehouseId('not-a-uuid'), throwsArgumentError);
      expect(
        () => DeviceId('018f7f65-8d31-7b84-bb46-4f47d82c1f70'),
        throwsArgumentError,
      );
      expect(
        () => SessionId('018f7f65-8d31-7b84-bb46-4f47d82c1f70'),
        throwsArgumentError,
      );
    });

    test('business-wide and warehouse scopes are explicit', () {
      const businessWide = BusinessWide();
      final warehouse = WarehouseScope(WarehouseId(warehouseId));

      expect(businessWide, isA<BusinessWide>());
      expect(warehouse.warehouseId.value, warehouseId);
      expect(businessWide, isNot(equals(warehouse)));
    });

    test('warehouse evidence and atomic actor invariants fail closed', () {
      final business = BusinessId(businessId);
      final actor = RemoteAuthUserId(actorId);
      expect(
        () => BusinessContext.verifiedMembership(
          businessId: business,
          memberAuthUserId: actor,
          role: 'owner',
          scope: WarehouseScope(WarehouseId(warehouseId)),
          warehouseMembershipBusinessId: BusinessId(otherBusinessId),
        ),
        throwsArgumentError,
      );

      final member = BusinessContext.verifiedMembership(
        businessId: business,
        memberAuthUserId: actor,
        role: 'employee',
        scope: const BusinessWide(),
      );
      expect(
        () => ExecutionContext.verifiedBusiness(
          session: SessionContext.verifiedRemote(
            sessionId: SessionId(sessionId),
            remoteAuthUserId: RemoteAuthUserId(otherActorId),
          ),
          business: member,
          deviceIdentity: DeviceId(deviceId),
        ),
        throwsArgumentError,
      );
    });
  });

  group('installation device identity', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('phase108e-device-');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('provisions once and is stable across store restarts', () async {
      final generator = _DeviceGenerator([deviceId, secondDeviceId]);
      final firstStore = FileDeviceIdentityStore(
        profileDirectory: directory,
        generator: generator,
      );

      final first = await firstStore.loadOrProvision();
      final restarted = FileDeviceIdentityStore(
        profileDirectory: directory,
        generator: generator,
      );
      final second = await restarted.loadOrProvision();

      expect(first, second);
      expect(generator.calls, 1);
      expect(
        File(path.join(directory.path, FileDeviceIdentityStore.fileName))
            .existsSync(),
        isTrue,
      );
    });

    test('corrupt state fails closed without silent regeneration', () async {
      final file = File(
        path.join(directory.path, FileDeviceIdentityStore.fileName),
      );
      await file.writeAsString('{"schemaVersion":1,"deviceId":"bad"}');
      final generator = _DeviceGenerator([deviceId]);
      final store = FileDeviceIdentityStore(
        profileDirectory: directory,
        generator: generator,
      );

      await expectLater(
        store.loadOrProvision(),
        throwsA(
          isA<DeviceIdentityStoreException>().having(
            (error) => error.code,
            'code',
            'corruptDeviceIdentity',
          ),
        ),
      );
      expect(generator.calls, 0);
    });

    test('reprovision is explicit and produces a different identity', () async {
      final generator = _DeviceGenerator([deviceId, secondDeviceId]);
      final store = FileDeviceIdentityStore(
        profileDirectory: directory,
        generator: generator,
      );

      expect((await store.loadOrProvision()).value, deviceId);
      expect((await store.reprovision()).value, secondDeviceId);
      expect((await store.loadOrProvision()).value, secondDeviceId);
      expect(generator.calls, 2);
    });

    test('device file is outside the business backup contract', () {
      final backupSource = File('lib/core/backup/backup_restore_service.dart')
          .readAsStringSync();
      expect(
        backupSource,
        isNot(contains(FileDeviceIdentityStore.fileName)),
      );
    });
  });

  group('version, tombstone, and time contracts', () {
    test('server version starts at one and advances exactly once', () {
      const created = EntityVersion.initial;
      final updated = created.nextAcceptedMutation();
      final deleted = updated.nextAcceptedMutation();
      final restored = deleted.nextAcceptedMutation();

      expect([created.value, updated.value, deleted.value, restored.value],
          [1, 2, 3, 4]);
      expect(() => EntityVersion(0), throwsArgumentError);
      expect(() => EntityVersion(-1), throwsArgumentError);
      expect(
        () => EntityVersion(EntityVersion.maxValue).nextAcceptedMutation(),
        throwsStateError,
      );
    });

    test('deletion metadata is explicit, versioned, and UTC-only', () {
      final version = EntityVersion(3);
      final deletion = DeletionMetadata(
        deletionVersion: version,
        deletedAtUtc: DateTime.utc(2026, 9, 8, 8),
        deletedByAuthUserId: RemoteAuthUserId(actorId),
        deletedByDeviceId: DeviceId(deviceId),
        sourceOperationId: OperationId(operationId),
      );
      final record = DistributedRecordMetadata(
        businessId: BusinessId(businessId),
        entityType: 'product',
        entityId: 'product-1',
        entityVersion: version,
        serverModifiedAtUtc: DateTime.utc(2026, 9, 8, 8),
        modifiedByAuthUserId: RemoteAuthUserId(actorId),
        modifiedByDeviceId: DeviceId(deviceId),
        sourceOperationId: OperationId(operationId),
        deletionMetadata: deletion,
      );

      expect(record.isDeleted, isTrue);
      expect(deletion.toJson()['deleted'], isTrue);
      expect(deletion.toJson()['deletedAtUtc'], endsWith('Z'));
      expect(
        () => DeletionMetadata(
          deletionVersion: version,
          deletedAtUtc: DateTime(2026, 9, 8),
          deletedByAuthUserId: RemoteAuthUserId(actorId),
          deletedByDeviceId: DeviceId(deviceId),
          sourceOperationId: OperationId(operationId),
        ),
        throwsArgumentError,
      );
    });

    test('fixed clock is deterministic and Cairo dates cross UTC boundaries',
        () {
      final clock = _FixedClock(DateTime.utc(2026, 1, 1, 22));
      expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 22));
      expect(
        BusinessDate.fromCairoInstant(DateTime.utc(2026, 1, 1, 21, 59)).value,
        '2026-01-01',
      );
      expect(
        BusinessDate.fromCairoInstant(DateTime.utc(2026, 1, 1, 22)).value,
        '2026-01-02',
      );
      expect(
        BusinessDate.fromCairoInstant(DateTime.utc(2026, 6, 1, 21)).value,
        '2026-06-02',
      );
      expect(() => BusinessDate('2026-02-30'), throwsArgumentError);
      expect(
        () => BusinessDate.fromCairoInstant(DateTime(2026, 1, 1)),
        throwsArgumentError,
      );
    });
  });
}

const businessId = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
const businessIdUpper = 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF';
const otherBusinessId = '22222222-2222-4222-8222-222222222222';
const warehouseId = '33333333-3333-4333-8333-333333333333';
const deviceId = '44444444-4444-4444-8444-444444444444';
const secondDeviceId = '55555555-5555-4555-8555-555555555555';
const sessionId = '66666666-6666-4666-8666-666666666666';
const actorId = '77777777-7777-4777-8777-777777777777';
const otherActorId = '88888888-8888-4888-8888-888888888888';
const operationId = '018f7f65-8d31-7b84-bb46-4f47d82c1f70';

final class _DeviceGenerator implements DeviceIdGenerator {
  _DeviceGenerator(this.values);

  final List<String> values;
  int calls = 0;

  @override
  DeviceId generate() => DeviceId(values[calls++]);
}

final class _FixedClock implements ApplicationClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}
