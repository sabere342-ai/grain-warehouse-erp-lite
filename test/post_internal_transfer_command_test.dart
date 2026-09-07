import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_internal_transfer_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_gateway.dart';

void main() {
  const commandId = '018f7f65-8d31-7b84-bb46-4f47d82c1f70';
  const businessId = '11111111-1111-4111-8111-111111111111';
  const sourceId = '22222222-2222-4222-8222-222222222222';
  const destinationId = '33333333-3333-4333-8333-333333333333';
  const reference = '018f7f65-8d31-7b84-bb46-4f47d82c1f71';
  const actorId = '44444444-4444-4444-8444-444444444444';

  PostInternalTransferCommand command({
    String id = commandId,
    String destination = destinationId,
    int amount = 1250,
    String? note = '   ',
  }) =>
      PostInternalTransferCommand(
        commandId: id,
        businessId: businessId,
        sourceFinancialAccountId: sourceId,
        destinationFinancialAccountId: destination,
        amountQirsh: amount,
        effectiveBusinessDate: '2026-09-06',
        transferReference: reference,
        note: note,
      );

  test('command normalizes exact payload and rejects invalid money/accounts',
      () {
    final value = command();
    expect(value.note, isNull);
    expect(value.schemaVersion, 1);
    expect(value.toGatewayPayload().amountQirsh, 1250);
    expect(value.canonicalPayloadJson, contains('"transferReference"'));
    expect(value.localFingerprint, hasLength(64));
    expect(() => command(amount: 0), throwsArgumentError);
    expect(() => command(destination: sourceId), throwsArgumentError);
    expect(() => command(id: 'bad'), throwsArgumentError);
    expect(
      () => PostInternalTransferCommand(
        commandId: commandId,
        schemaVersion: 2,
        businessId: businessId,
        sourceFinancialAccountId: sourceId,
        destinationFinancialAccountId: destinationId,
        amountQirsh: 1,
        effectiveBusinessDate: '2026-02-30',
        transferReference: reference,
      ),
      throwsArgumentError,
    );
  });

  group('handler authority, idempotency and recovery', () {
    late MutableSessionContextProvider sessions;
    late MutableBusinessContextProvider businesses;
    late _AttemptStore attempts;
    late _Gateway gateway;
    late _Projection projection;

    setUp(() {
      sessions = MutableSessionContextProvider()
        ..replace(const SessionContext.verifiedRemote(
          remoteAuthUserId: actorId,
        ));
      businesses = MutableBusinessContextProvider()
        ..replace(const BusinessContext.verifiedMembership(
          businessId: businessId,
          memberAuthUserId: actorId,
          role: 'owner',
        ));
      attempts = _AttemptStore();
      gateway = _Gateway(_success());
      projection = _Projection();
    });

    PostInternalTransferCommandHandler handler() =>
        PostInternalTransferCommandHandler(
          sessionContextProvider: sessions,
          businessContextProvider: businesses,
          attemptStore: attempts,
          gateway: gateway,
          projectionWriter: projection,
        );

    ApplicationCommandRequest<PostInternalTransferCommand> request(
      PostInternalTransferCommand value,
    ) =>
        ApplicationCommandRequest(
          command: value,
          businessContext: businesses.current,
          idempotencyKey: value.commandId,
        );

    test('requires verified owner and does not persist while known offline',
        () async {
      sessions.replace(const SessionContext(userId: 'local'));
      final offline = await handler().execute(request(command()));
      expect((offline as PostInternalTransferFailure).code,
          'unauthenticated.sessionRequired');
      expect(attempts.events, isEmpty);
      expect(gateway.calls, 0);

      sessions.replace(const SessionContext.verifiedRemote(
        remoteAuthUserId: actorId,
      ));
      businesses.replace(const BusinessContext.verifiedMembership(
        businessId: businessId,
        memberAuthUserId: actorId,
        role: 'employee',
      ));
      final employee = await handler().execute(request(command()));
      expect((employee as PostInternalTransferFailure).code,
          'wrongBusinessContext');
      expect(gateway.calls, 0);
    });

    test('success persists before transport and projects exactly once',
        () async {
      final result = await handler().execute(request(command()));
      expect(result, isA<PostInternalTransferSuccess>());
      expect(
          attempts.events.take(3), ['prepare', 'sending', 'serverConfirmed']);
      expect(attempts.events.last, 'confirmed');
      expect(projection.calls, 1);
      expect(gateway.calls, 1);
    });

    test('unknown outcome retry preserves command ID and exact payload',
        () async {
      gateway.response = const InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.connectivity,
        code: 'serverUnavailable',
        retryable: true,
      );
      final first = await handler().execute(request(command()));
      expect((first as PostInternalTransferFailure).code, 'serverUnavailable');
      expect(attempts.stored?.state,
          InternalTransferPostingAttemptState.unknownOutcome);

      gateway.response = _success(replayed: true);
      final retry = await handler().execute(request(command()));
      expect(retry, isA<PostInternalTransferSuccess>());
      expect(gateway.commandIds, [commandId, commandId]);
      expect(gateway.payloads[0], gateway.payloads[1]);
    });

    test('same key changed payload conflicts before a second transport',
        () async {
      await handler().execute(request(command()));
      gateway.calls = 0;
      final result = await handler().execute(request(command(amount: 1300)));
      expect(
          (result as PostInternalTransferFailure).code, 'idempotencyConflict');
      expect(gateway.calls, 0);
    });

    test('projection failure repairs locally without reposting money',
        () async {
      projection.error = StateError('injected');
      final first = await handler().execute(request(command()));
      expect((first as PostInternalTransferSuccess).projectionPending, isTrue);
      expect(gateway.calls, 1);

      projection.error = null;
      final repaired = await handler().execute(request(command()));
      expect(
          (repaired as PostInternalTransferSuccess).projectionPending, isFalse);
      expect(gateway.calls, 1);
      expect(projection.calls, 2);
    });

    test('invalid success envelope remains unknown and never projects',
        () async {
      gateway.response = InternalTransferPostingGatewaySuccess(
        commandId: commandId,
        businessId: businessId,
        transferId: 'not-a-uuid',
        displayNumber: 'TR-000001',
        transferReference: reference,
        sourceFinancialAccountId: sourceId,
        destinationFinancialAccountId: destinationId,
        sourceFinancialEntryId: '66666666-6666-4666-8666-666666666666',
        destinationFinancialEntryId: '77777777-7777-4777-8777-777777777777',
        auditEventIds: const [
          '88888888-8888-4888-8888-888888888888',
          '99999999-9999-4999-8999-999999999999',
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ],
        effectiveBusinessDate: '2026-09-06',
        amountQirsh: 1250,
        sourceBalanceAfterQirsh: 8750,
        destinationBalanceAfterQirsh: 6250,
        serverAcceptedAtUtc: DateTime.utc(2026, 9, 6, 10),
        replayed: false,
      );
      final result = await handler().execute(request(command()));
      expect((result as PostInternalTransferFailure).code,
          'unexpectedServerError');
      expect(attempts.stored?.state,
          InternalTransferPostingAttemptState.unknownOutcome);
      expect(projection.calls, 0);
    });
  });
}

InternalTransferPostingGatewaySuccess _success({bool replayed = false}) =>
    InternalTransferPostingGatewaySuccess(
      commandId: '018f7f65-8d31-7b84-bb46-4f47d82c1f70',
      businessId: '11111111-1111-4111-8111-111111111111',
      transferId: '55555555-5555-4555-8555-555555555555',
      displayNumber: 'TR-000001',
      transferReference: '018f7f65-8d31-7b84-bb46-4f47d82c1f71',
      sourceFinancialAccountId: '22222222-2222-4222-8222-222222222222',
      destinationFinancialAccountId: '33333333-3333-4333-8333-333333333333',
      sourceFinancialEntryId: '66666666-6666-4666-8666-666666666666',
      destinationFinancialEntryId: '77777777-7777-4777-8777-777777777777',
      auditEventIds: const [
        '88888888-8888-4888-8888-888888888888',
        '99999999-9999-4999-8999-999999999999',
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ],
      effectiveBusinessDate: '2026-09-06',
      amountQirsh: 1250,
      sourceBalanceAfterQirsh: 8750,
      destinationBalanceAfterQirsh: 6250,
      serverAcceptedAtUtc: DateTime.utc(2026, 9, 6, 10),
      replayed: replayed,
    );

final class _AttemptStore implements InternalTransferPostingAttemptStore {
  InternalTransferPostingAttempt? stored;
  final List<String> events = [];

  @override
  Future<InternalTransferPostingAttempt> prepare({
    required String commandId,
    required String businessId,
    required String canonicalPayloadJson,
    required String localFingerprint,
  }) async {
    events.add('prepare');
    final existing = stored;
    if (existing != null) {
      if (existing.commandId != commandId ||
          existing.businessId != businessId ||
          existing.canonicalPayloadJson != canonicalPayloadJson ||
          existing.localFingerprint != localFingerprint) {
        throw const InternalTransferPostingAttemptConflictException();
      }
      return existing;
    }
    return stored = InternalTransferPostingAttempt(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: canonicalPayloadJson,
      localFingerprint: localFingerprint,
      state: InternalTransferPostingAttemptState.queued,
      createdAtUtc: DateTime.utc(2026, 9, 6),
      updatedAtUtc: DateTime.utc(2026, 9, 6),
    );
  }

  @override
  Future<InternalTransferPostingAttempt?> load(String commandId) async =>
      stored?.commandId == commandId ? stored : null;

  @override
  Future<List<InternalTransferPostingAttempt>> loadIncompleteForBusiness(
    String businessId,
  ) async =>
      stored == null ? const [] : [stored!];

  @override
  Future<void> markSending(String commandId) async {
    events.add('sending');
    _replace(
      state: InternalTransferPostingAttemptState.sending,
      attempts: stored!.attemptCount + 1,
    );
  }

  @override
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  ) async {
    events.add('serverConfirmed');
    _replace(
      state: InternalTransferPostingAttemptState.confirmedProjectionPending,
      result: canonicalServerResultJson,
    );
  }

  @override
  Future<void> markConfirmed(String commandId) async {
    events.add('confirmed');
    _replace(state: InternalTransferPostingAttemptState.confirmed);
  }

  @override
  Future<void> markFailure(
    String commandId, {
    required InternalTransferPostingAttemptState state,
    required String errorCode,
  }) async {
    events.add(state.name);
    _replace(state: state, error: errorCode);
  }

  void _replace({
    required InternalTransferPostingAttemptState state,
    String? result,
    String? error,
    int? attempts,
  }) {
    final value = stored!;
    stored = InternalTransferPostingAttempt(
      commandId: value.commandId,
      businessId: value.businessId,
      canonicalPayloadJson: value.canonicalPayloadJson,
      localFingerprint: value.localFingerprint,
      state: state,
      canonicalServerResultJson: result ?? value.canonicalServerResultJson,
      createdAtUtc: value.createdAtUtc,
      updatedAtUtc: DateTime.utc(2026, 9, 6, 1),
      attemptCount: attempts ?? value.attemptCount,
      lastErrorCode: error,
    );
  }
}

final class _Gateway implements InternalTransferPostingGateway {
  _Gateway(this.response);
  InternalTransferPostingGatewayResponse response;
  int calls = 0;
  final List<String> commandIds = [];
  final List<Map<String, Object?>> payloads = [];

  @override
  Future<InternalTransferPostingGatewayResponse> post(
    InternalTransferPostingRequestPayload payload,
  ) async {
    calls++;
    commandIds.add(payload.commandId);
    payloads.add(payload.toCanonicalMap());
    return response;
  }
}

final class _Projection implements ConfirmedInternalTransferProjectionWriter {
  int calls = 0;
  Object? error;

  @override
  Future<void> project(ConfirmedInternalTransferProjection value) async {
    calls++;
    if (error != null) throw error!;
  }
}
