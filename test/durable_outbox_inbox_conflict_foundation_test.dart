import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_conflict.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/durable_operation.dart';
import 'package:grain_warehouse_erp_lite/application/distributed_state/distributed_record_metadata.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/application/time/application_clock.dart';
import 'package:grain_warehouse_erp_lite/core/distributed_state/drift_durable_sync_store.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const _businessId = '11111111-1111-4111-8111-111111111111';
const _otherBusinessId = '22222222-2222-4222-8222-222222222222';
const _actorId = '33333333-3333-4333-8333-333333333333';
const _deviceId = '44444444-4444-4444-8444-444444444444';
const _sessionId = '55555555-5555-4555-8555-555555555555';
const _operationId = '66666666-6666-4666-8666-666666666666';
const _inboundId = '77777777-7777-4777-8777-777777777777';
const _conflictId = '88888888-8888-4888-8888-888888888888';

void main() {
  late _MutableClock clock;
  late FoundationDatabase database;
  late DriftDurableSyncStore store;

  setUp(() {
    clock = _MutableClock(DateTime.utc(2026, 9, 10, 12));
    database = openInMemoryTestDatabase();
    store = DriftDurableSyncStore(database, clock: clock);
  });

  tearDown(() => database.close());

  test('schema 18 creates four additive durable tables and v17 preserves data',
      () async {
    final directory = await Directory.systemTemp.createTemp('durable-v17-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fileDatabase = openDatabaseFile(file);
    await fileDatabase.writeProbe('preserved', 'yes');
    await fileDatabase.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('PRAGMA foreign_keys = OFF');
    legacy.execute('DROP TABLE durable_inbox_operations');
    legacy.execute('DROP TABLE durable_conflicts');
    legacy.execute('DROP TABLE durable_sync_checkpoints');
    legacy.execute('DROP TABLE durable_outbox_operations');
    legacy.execute('PRAGMA user_version = 17');
    legacy.dispose();

    fileDatabase = openDatabaseFile(file);
    expect(fileDatabase.schemaVersion, 18);
    expect(await fileDatabase.readProbe('preserved'), 'yes');
    final names = (await fileDatabase
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      names,
      containsAll(<String>{
        'durable_outbox_operations',
        'durable_inbox_operations',
        'durable_conflicts',
        'durable_sync_checkpoints',
      }),
    );
    await fileDatabase.close();
  });

  test('outbox exact replay is stable and changed payload fails closed',
      () async {
    final envelope = _outbox(clock.nowUtc());
    final first = await store.enqueue(envelope);
    final replay = await store.enqueue(envelope);
    expect(replay.recordVersion, first.recordVersion);
    expect(await database.select(database.durableOutboxOperations).get(),
        hasLength(1));

    expect(
      () => store.enqueue(_outbox(clock.nowUtc(), payload: '{"value":2}')),
      throwsA(isA<DurableIdentityConflictException>()),
    );
  });

  test('local mutation and outbox insert commit or roll back together',
      () async {
    final envelope = _outbox(clock.nowUtc());
    await store.enqueueWithMutation(envelope, () async {
      await database.writeProbe('atomic-success', 'yes');
    });
    expect(await database.readProbe('atomic-success'), 'yes');
    expect(await store.loadOutbox(_scope(), _operationId), isNotNull);

    expect(
      () => store.enqueueWithMutation(
        _outbox(clock.nowUtc(), payload: '{"value":2}'),
        () => database.writeProbe('must-rollback', 'no'),
      ),
      throwsA(isA<DurableIdentityConflictException>()),
    );
    expect(await database.readProbe('must-rollback'), isNull);
  });

  test('one claim owns transitions and stale claims recover durably', () async {
    await store.enqueue(_outbox(clock.nowUtc()));
    final claims = await Future.wait([
      store.claimNextOutbox(
        _scope(),
        nowUtc: clock.nowUtc(),
        leaseDuration: const Duration(minutes: 1),
      ),
      store.claimNextOutbox(
        _scope(),
        nowUtc: clock.nowUtc(),
        leaseDuration: const Duration(minutes: 1),
      ),
    ]);
    expect(claims.whereType<DurableOutboxOperation>(), hasLength(1));
    final claim = claims.whereType<DurableOutboxOperation>().single;
    expect(claim.claimToken, isNotNull);
    expect(claim.attemptCount, 1);

    clock.advance(const Duration(minutes: 2));
    expect(
      () => store.retryOutbox(
        _scope(),
        _operationId,
        expectedRecordVersion: claim.recordVersion,
        claimToken: claim.claimToken!,
        nextAttemptAtUtc: clock.nowUtc(),
        errorClass: DurableErrorClass.timeout,
        errorCode: 'timeout',
      ),
      throwsA(isA<DurableLostRaceException>()),
    );
    expect(await store.recoverExpiredOutboxClaims(clock.nowUtc()), 1);
    final recovered = await store.loadOutbox(_scope(), _operationId);
    expect(recovered!.state, DurableOutboxState.retryWait);
    expect(recovered.lastErrorClass, DurableErrorClass.staleClaimRecovered);
    expect(recovered.claimToken, isNull);
  });

  test('acknowledgement survives file restart and is never made sendable',
      () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('durable-ack-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fileDatabase = openDatabaseFile(file);
    var fileStore = DriftDurableSyncStore(fileDatabase, clock: clock);
    await fileStore.enqueue(_outbox(clock.nowUtc()));
    final claim = await fileStore.claimOutbox(
      _scope(),
      _operationId,
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    const ackJson = '{"accepted":true}';
    await fileStore.acknowledgeOutbox(
      _scope(),
      _operationId,
      expectedRecordVersion: claim.recordVersion,
      claimToken: claim.claimToken!,
      acknowledgement: DurableAcknowledgement(
        schemaVersion: 1,
        payloadJson: ackJson,
        payloadFingerprint: payloadFingerprint(ackJson),
        serverAcceptedAtUtc: clock.nowUtc(),
      ),
    );
    await fileDatabase.close();

    fileDatabase = openDatabaseFile(file);
    fileStore = DriftDurableSyncStore(fileDatabase, clock: clock);
    final restored = await fileStore.loadOutbox(_scope(), _operationId);
    expect(restored!.state, DurableOutboxState.acknowledgedPendingApply);
    expect(restored.acknowledgement!.payloadJson, ackJson);
    expect(
      await fileStore.listEligibleOutbox(_scope(), clock.nowUtc()),
      isEmpty,
    );
    await fileStore.completeOutbox(
      _scope(),
      _operationId,
      expectedRecordVersion: restored.recordVersion,
    );
    await fileDatabase.close();
    database = openInMemoryTestDatabase();
  });

  test('pending retry inbox conflict and checkpoint all survive restart',
      () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('durable-states-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var fileDatabase = openDatabaseFile(file);
    var fileStore = DriftDurableSyncStore(fileDatabase, clock: clock);
    await fileStore.enqueue(_outbox(clock.nowUtc()));
    const retryId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final retryEnvelope = _outboxFor(retryId, clock.nowUtc());
    await fileStore.enqueue(retryEnvelope);
    final retryClaim = await fileStore.claimOutbox(
      _scope(),
      retryId,
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    await fileStore.retryOutbox(
      _scope(),
      retryId,
      expectedRecordVersion: retryClaim.recordVersion,
      claimToken: retryClaim.claimToken!,
      nextAttemptAtUtc: clock.nowUtc().add(const Duration(hours: 1)),
      errorClass: DurableErrorClass.connectivity,
      errorCode: 'offline',
    );
    await fileStore.receive(_inbox(clock.nowUtc()));

    const conflictInboundId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    await fileStore.receive(_inboxFor(conflictInboundId, clock.nowUtc()));
    final conflictClaim = await fileStore.claimNextInbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    // The first receipt is claimed first and remains a durable conflict.
    final conflictEvidence = DurableConflictEvidence(
      conflictId: _conflictId,
      scope: _scope(),
      entityType: 'product',
      entityId: 'product-restart',
      localPayloadJson: '{"name":"local"}',
      remotePayloadJson: '{"name":"remote"}',
      remoteOperationId:
          OperationId(conflictClaim!.envelope.sourceOperationId.value),
      remoteSourceAuthority: 'authority-a',
      classification: DurableConflictClassification.versionMismatch,
      detectedAtUtc: clock.nowUtc(),
    );
    await fileStore.conflictInbox(
      _scope(),
      'authority-a',
      conflictClaim.envelope.sourceOperationId.value,
      expectedRecordVersion: conflictClaim.recordVersion,
      claimToken: conflictClaim.claimToken!,
      evidence: conflictEvidence,
    );

    final checkpointClaim = await fileStore.claimNextInbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    await fileStore.applyInbound<void>(
      _scope(),
      'authority-a',
      checkpointClaim!.envelope.sourceOperationId.value,
      expectedRecordVersion: checkpointClaim.recordVersion,
      claimToken: checkpointClaim.claimToken!,
      mutation: (_) async {},
      checkpoint: DurableCheckpoint(
        scope: _scope(),
        sourceAuthority: 'authority-a',
        streamName: 'restart-stream',
        cursorValue: 'opaque-restart',
        lastSourceOperationId: checkpointClaim.envelope.sourceOperationId,
        updatedAtUtc: clock.nowUtc(),
        recordVersion: 1,
      ),
    );
    await fileDatabase.close();

    fileDatabase = openDatabaseFile(file);
    fileStore = DriftDurableSyncStore(fileDatabase, clock: clock);
    expect(
      (await fileStore.loadOutbox(_scope(), _operationId))!.state,
      DurableOutboxState.pending,
    );
    expect(
      (await fileStore.loadOutbox(_scope(), retryId))!.state,
      DurableOutboxState.retryWait,
    );
    expect(await fileStore.listUnresolvedConflicts(_scope()), hasLength(1));
    expect(
      (await fileStore.loadCheckpoint(
        _scope(),
        'authority-a',
        'restart-stream',
      ))!
          .cursorValue,
      'opaque-restart',
    );
    await fileDatabase.close();
    database = openInMemoryTestDatabase();
  });

  test('inbox exact duplicates apply at most once with atomic checkpoint',
      () async {
    final envelope = _inbox(clock.nowUtc());
    await store.receive(envelope);
    final claim = await store.claimNextInbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    var applications = 0;
    await store.applyInbound(
      _scope(),
      'authority-a',
      _inboundId,
      expectedRecordVersion: claim!.recordVersion,
      claimToken: claim.claimToken!,
      mutation: (_) async {
        applications++;
        await database.writeProbe('inbound-business', 'applied');
      },
      checkpoint: DurableCheckpoint(
        scope: _scope(),
        sourceAuthority: 'authority-a',
        streamName: 'products-v1',
        cursorValue: 'opaque-0001',
        lastSourceOperationId: OperationId(_inboundId),
        updatedAtUtc: clock.nowUtc(),
        recordVersion: 1,
      ),
    );
    final duplicate = await store.receive(envelope);
    expect(duplicate.state, DurableInboxState.applied);
    expect(
      await store.claimNextInbox(
        _scope(),
        nowUtc: clock.nowUtc(),
        leaseDuration: const Duration(minutes: 5),
      ),
      isNull,
    );
    expect(applications, 1);
    expect(await database.readProbe('inbound-business'), 'applied');
    expect(
      (await store.loadCheckpoint(_scope(), 'authority-a', 'products-v1'))!
          .cursorValue,
      'opaque-0001',
    );
  });

  test('changed inbound payload is rejected before applier', () async {
    await store.receive(_inbox(clock.nowUtc()));
    expect(
      () => store.receive(_inbox(clock.nowUtc(), payload: '{"name":"b"}')),
      throwsA(isA<DurableIdentityConflictException>()),
    );
  });

  test('inbound mutation failure cannot leave mutation or APPLIED marker',
      () async {
    await store.receive(_inbox(clock.nowUtc()));
    final claim = await store.claimNextInbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    expect(
      () => store.applyInbound<void>(
        _scope(),
        'authority-a',
        _inboundId,
        expectedRecordVersion: claim!.recordVersion,
        claimToken: claim.claimToken!,
        mutation: (_) async {
          await database.writeProbe('rolled-back-inbound', 'bad');
          throw StateError('crash');
        },
      ),
      throwsStateError,
    );
    expect(await database.readProbe('rolled-back-inbound'), isNull);
    expect(
      (await store.loadInbox(_scope(), 'authority-a', _inboundId))!.state,
      DurableInboxState.applying,
    );
  });

  test('conflict disposition requires and preserves durable evidence',
      () async {
    await store.receive(_inbox(clock.nowUtc()));
    final claim = await store.claimNextInbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    final deletion = DeletionMetadata(
      deletionVersion: EntityVersion(3),
      deletedAtUtc: clock.nowUtc(),
      deletedByAuthUserId: RemoteAuthUserId(_actorId),
      deletedByDeviceId: DeviceId(_deviceId),
      sourceOperationId: OperationId(_inboundId),
    );
    final evidence = DurableConflictEvidence(
      conflictId: _conflictId,
      scope: _scope(),
      entityType: 'product',
      entityId: 'product-1',
      localEntityVersion: EntityVersion(2),
      remoteEntityVersion: EntityVersion(3),
      localPayloadJson: '{"name":"local"}',
      remotePayloadJson: 'null',
      remoteOperationId: OperationId(_inboundId),
      remoteSourceAuthority: 'authority-a',
      remoteDeletionMetadata: deletion,
      classification: DurableConflictClassification.deleteVsUpdate,
      detectedAtUtc: clock.nowUtc(),
    );
    await store.conflictInbox(
      _scope(),
      'authority-a',
      _inboundId,
      expectedRecordVersion: claim!.recordVersion,
      claimToken: claim.claimToken!,
      evidence: evidence,
    );
    final inbox = await store.loadInbox(_scope(), 'authority-a', _inboundId);
    expect(inbox!.state, DurableInboxState.conflict);
    expect(inbox.conflictId, _conflictId);
    final conflicts = await store.listUnresolvedConflicts(_scope());
    expect(conflicts, hasLength(1));
    expect(conflicts.single.evidence.remoteDeletionMetadata, isNotNull);
    expect((await store.recordConflict(evidence)).evidence.conflictId,
        _conflictId);
  });

  test('outbox projection mismatch is durably terminal and queryable',
      () async {
    await store.enqueue(_outbox(clock.nowUtc()));
    final claim = await store.claimNextOutbox(
      _scope(),
      nowUtc: clock.nowUtc(),
      leaseDuration: const Duration(minutes: 5),
    );
    final evidence = DurableConflictEvidence(
      conflictId: _conflictId,
      scope: _scope(),
      entityType: 'probe',
      entityId: 'probe-1',
      localPayloadJson: '{"value":1}',
      remotePayloadJson: '{"value":2}',
      localOperationId: OperationId(_operationId),
      classification:
          DurableConflictClassification.acknowledgedProjectionMismatch,
      detectedAtUtc: clock.nowUtc(),
    );

    await store.conflictOutbox(
      _scope(),
      _operationId,
      expectedRecordVersion: claim!.recordVersion,
      evidence: evidence,
    );

    final operation = await store.loadOutbox(_scope(), _operationId);
    expect(operation!.state, DurableOutboxState.conflict);
    expect(operation.conflictId, _conflictId);
    expect(await store.listEligibleOutbox(_scope(), clock.nowUtc()), isEmpty);
    final conflicts = await store.listUnresolvedConflicts(_scope());
    expect(conflicts.single.evidence.classification,
        DurableConflictClassification.acknowledgedProjectionMismatch);
  });

  test('all scoped reads reject cross-business access', () async {
    await store.enqueue(_outbox(clock.nowUtc()));
    await store.receive(_inbox(clock.nowUtc()));
    expect(await store.loadOutbox(_otherScope(), _operationId), isNull);
    expect(await store.loadInbox(_otherScope(), 'authority-a', _inboundId),
        isNull);
    expect(await store.listUnresolvedConflicts(_otherScope()), isEmpty);
  });

  test('new expense attempts use generic outbox and legacy fallback remains',
      () async {
    final attemptStore = DriftExpensePostingAttemptStore(
      database,
      financialAccountRepository:
          await DriftFinancialAccountRepository.open(database),
      clock: clock,
      durableSyncStore: store,
    );
    const genericId = '99999999-9999-4999-8999-999999999999';
    const payload = '{"amount":10}';
    await attemptStore.prepareDurable(
      commandId: genericId,
      businessId: _businessId,
      canonicalPayloadJson: payload,
      localFingerprint: payloadFingerprint(payload),
      executionContext: _context(),
      businessDate: BusinessDate('2026-09-10'),
    );
    expect(
        await database.select(database.expensePostingAttempts).get(), isEmpty);
    expect(await database.select(database.durableOutboxOperations).get(),
        hasLength(1));

    const legacyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await attemptStore.prepare(
      commandId: legacyId,
      businessId: _businessId,
      canonicalPayloadJson: payload,
      localFingerprint: payloadFingerprint(payload),
    );
    expect(await database.select(database.expensePostingAttempts).get(),
        hasLength(1));
    expect(await database.select(database.durableOutboxOperations).get(),
        hasLength(1));
  });

  test(
      'new internal transfer attempts use generic outbox and legacy fallback remains',
      () async {
    final attemptStore = DriftInternalTransferPostingAttemptStore(
      database,
      clock: clock,
      durableSyncStore: store,
    );
    const genericId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    const legacyId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
    const payload = '{"amount":10}';
    await attemptStore.prepareDurable(
      commandId: genericId,
      businessId: _businessId,
      canonicalPayloadJson: payload,
      localFingerprint: payloadFingerprint(payload),
      executionContext: _context(),
      businessDate: BusinessDate('2026-09-10'),
    );
    expect(
      await database.select(database.internalTransferPostingAttempts).get(),
      isEmpty,
    );
    expect(await database.select(database.durableOutboxOperations).get(),
        hasLength(1));
    await attemptStore.prepare(
      commandId: legacyId,
      businessId: _businessId,
      canonicalPayloadJson: payload,
      localFingerprint: payloadFingerprint(payload),
    );
    expect(
      await database.select(database.internalTransferPostingAttempts).get(),
      hasLength(1),
    );
    expect(await database.select(database.durableOutboxOperations).get(),
        hasLength(1));
  });
}

DurableScope _scope() => DurableScope(
      businessId: BusinessId(_businessId),
      kind: DurableScopeKind.businessWide,
    );

DurableScope _otherScope() => DurableScope(
      businessId: BusinessId(_otherBusinessId),
      kind: DurableScopeKind.businessWide,
    );

ExecutionContext _context() => ExecutionContext.verifiedBusiness(
      session: SessionContext.verifiedRemote(
        sessionId: SessionId(_sessionId),
        remoteAuthUserId: RemoteAuthUserId(_actorId),
      ),
      business: BusinessContext.verifiedMembership(
        businessId: BusinessId(_businessId),
        memberAuthUserId: RemoteAuthUserId(_actorId),
        role: 'owner',
        scope: const BusinessWide(),
      ),
      deviceIdentity: DeviceId(_deviceId),
    );

DurableOutboxEnvelope _outbox(
  DateTime now, {
  String payload = '{"value":1}',
}) =>
    DurableOutboxEnvelope.fromExecutionContext(
      operationId: OperationId(_operationId),
      idempotencyKey: _operationId,
      context: _context(),
      operationKind: 'test.operation.v1',
      aggregateType: 'probe',
      aggregateId: 'probe-1',
      payloadSchemaVersion: 1,
      payloadJson: payload,
      payloadFingerprint: payloadFingerprint(payload),
      occurredAtUtc: now,
    );

DurableOutboxEnvelope _outboxFor(String operationId, DateTime now) =>
    DurableOutboxEnvelope.fromExecutionContext(
      operationId: OperationId(operationId),
      idempotencyKey: operationId,
      context: _context(),
      operationKind: 'test.operation.v1',
      aggregateType: 'probe',
      aggregateId: operationId,
      payloadSchemaVersion: 1,
      payloadJson: '{"operationId":"$operationId"}',
      payloadFingerprint: payloadFingerprint('{"operationId":"$operationId"}'),
      occurredAtUtc: now,
    );

DurableInboxEnvelope _inbox(
  DateTime now, {
  String payload = '{"name":"a"}',
}) =>
    DurableInboxEnvelope(
      sourceAuthority: 'authority-a',
      sourceOperationId: OperationId(_inboundId),
      scope: _scope(),
      operationKind: 'product.upsert.v1',
      aggregateType: 'product',
      aggregateId: 'product-1',
      payloadSchemaVersion: 1,
      payloadJson: payload,
      payloadFingerprint: payloadFingerprint(payload),
      sourceActorAuthUserId: RemoteAuthUserId(_actorId),
      sourceDeviceId: DeviceId(_deviceId),
      remoteEntityVersion: EntityVersion(2),
      serverOccurredAtUtc: now,
    );

DurableInboxEnvelope _inboxFor(String operationId, DateTime now) =>
    DurableInboxEnvelope(
      sourceAuthority: 'authority-a',
      sourceOperationId: OperationId(operationId),
      scope: _scope(),
      operationKind: 'product.upsert.v1',
      aggregateType: 'product',
      aggregateId: operationId,
      payloadSchemaVersion: 1,
      payloadJson: '{"operationId":"$operationId"}',
      payloadFingerprint: payloadFingerprint('{"operationId":"$operationId"}'),
      sourceActorAuthUserId: RemoteAuthUserId(_actorId),
      sourceDeviceId: DeviceId(_deviceId),
      remoteEntityVersion: EntityVersion(2),
      serverOccurredAtUtc: now,
    );

final class _MutableClock implements ApplicationClock {
  _MutableClock(this.value);
  DateTime value;

  @override
  DateTime nowUtc() => value;

  void advance(Duration duration) => value = value.add(duration);
}
