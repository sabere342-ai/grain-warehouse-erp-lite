import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_expense_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

void main() {
  const commandId = '018f7f65-8d31-7b84-bb46-4f47d82c1f70';
  const businessId = '11111111-1111-4111-8111-111111111111';
  const accountId = '22222222-2222-4222-8222-222222222222';

  PostExpenseCommand command({
    String id = commandId,
    String category = '  نقل  ',
    String? notes = '   ',
    int amount = 1250,
  }) =>
      PostExpenseCommand(
        commandId: id,
        businessId: businessId,
        businessDate: '2026-08-23',
        category: category,
        amountQirsh: amount,
        notes: notes,
        financialAccountId: accountId,
        paymentMethod: PaymentMethod.cash,
        accountingClassification: ExpenseAccountingClassification.operating,
      );

  group('PostExpenseCommand contract', () {
    test('normalizes transport fields and produces deterministic payload', () {
      final value = command();

      expect(value.schemaVersion, 1);
      expect(value.category, 'نقل');
      expect(value.notes, isNull);
      expect(value.canonicalPayloadJson, contains('"amountQirsh":1250'));
      expect(value.toGatewayPayload().commandId, commandId);
      expect(value.toGatewayPayload().paymentMethod, 'cash');
      expect(value.toGatewayPayload().accountingClassification, 'operating');
    });

    test('rejects malformed UUIDs, schema, date, amount, category and cheque',
        () {
      expect(() => command(id: 'not-a-uuid'), throwsArgumentError);
      expect(
        () => PostExpenseCommand(
          commandId: commandId,
          schemaVersion: 2,
          businessId: businessId,
          businessDate: '2026-02-30',
          category: 'x',
          amountQirsh: 1,
          financialAccountId: accountId,
          paymentMethod: PaymentMethod.cash,
          accountingClassification: ExpenseAccountingClassification.operating,
        ),
        throwsArgumentError,
      );
      expect(() => command(amount: 0), throwsArgumentError);
      expect(() => command(category: '  '), throwsArgumentError);
      expect(
        () => PostExpenseCommand(
          commandId: commandId,
          businessId: businessId,
          businessDate: '2026-08-23',
          category: 'x',
          amountQirsh: 1,
          financialAccountId: accountId,
          paymentMethod: PaymentMethod.check,
          accountingClassification: ExpenseAccountingClassification.operating,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PostExpenseCommandHandler', () {
    late MutableSessionContextProvider sessions;
    late MutableBusinessContextProvider businesses;
    late _AttemptStoreSpy attempts;
    late _GatewaySpy gateway;
    late _ProjectionSpy projection;

    setUp(() {
      sessions = MutableSessionContextProvider()
        ..replace(const SessionContext.verifiedRemote(
          remoteAuthUserId: '33333333-3333-4333-8333-333333333333',
        ));
      businesses = MutableBusinessContextProvider()
        ..replace(const BusinessContext.verifiedMembership(
          businessId: businessId,
          memberAuthUserId: '33333333-3333-4333-8333-333333333333',
          role: 'employee',
        ));
      attempts = _AttemptStoreSpy();
      gateway = _GatewaySpy(_success(commandId, businessId));
      projection = _ProjectionSpy();
    });

    PostExpenseCommandHandler handler() => PostExpenseCommandHandler(
          sessionContextProvider: sessions,
          businessContextProvider: businesses,
          attemptStore: attempts,
          gateway: gateway,
          projectionWriter: projection,
        );

    ApplicationCommandRequest<PostExpenseCommand> request(
      PostExpenseCommand value,
    ) =>
        ApplicationCommandRequest(
          command: value,
          businessContext: businesses.current,
          idempotencyKey: value.commandId,
        );

    test('requires a verified remote session and verified business context',
        () async {
      sessions.replace(const SessionContext(userId: 'local-only'));
      final noSession = await handler().execute(request(command()));
      expect(noSession, isA<PostExpenseFailure>());
      expect((noSession as PostExpenseFailure).code,
          'unauthenticated.sessionRequired');
      expect(gateway.calls, 0);

      sessions.replace(const SessionContext.verifiedRemote(
        remoteAuthUserId: '33333333-3333-4333-8333-333333333333',
      ));
      businesses.clear();
      final noBusiness = await handler().execute(
        ApplicationCommandRequest(
          command: command(),
          idempotencyKey: commandId,
        ),
      );
      expect((noBusiness as PostExpenseFailure).code, 'wrongBusinessContext');
      expect(gateway.calls, 0);
    });

    test('rejects request/command key mismatch before persistence', () async {
      final result = await handler().execute(
        ApplicationCommandRequest(
          command: command(),
          businessContext: businesses.current,
          idempotencyKey: '44444444-4444-4444-8444-444444444444',
        ),
      );

      expect((result as PostExpenseFailure).code, 'validation.invalidField');
      expect(attempts.events, isEmpty);
      expect(gateway.calls, 0);
    });

    test('stores the exact attempt before first transport and projects once',
        () async {
      final result = await handler().execute(request(command()));

      expect(result, isA<PostExpenseSuccess>());
      expect(
          attempts.events.take(3), ['prepare', 'sending', 'serverConfirmed']);
      expect(projection.calls, 1);
      expect(attempts.events.last, 'confirmed');
    });

    test('exact unknown-outcome retry reuses command ID and payload', () async {
      gateway.response = const ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.connectivity,
        code: 'serverUnavailable',
        retryable: true,
      );
      final first = await handler().execute(request(command()));
      expect((first as PostExpenseFailure).code, 'serverUnavailable');
      expect(attempts.lastState, ExpensePostingAttemptState.unknownOutcome);

      gateway.response = _success(commandId, businessId, replayed: true);
      final retry = await handler().execute(request(command()));

      expect(retry, isA<PostExpenseSuccess>());
      expect(gateway.commandIds, [commandId, commandId]);
      expect(gateway.payloads[0], gateway.payloads[1]);
    });

    test('local same-key payload conflict never reaches transport', () async {
      await handler().execute(request(command()));
      gateway.calls = 0;

      final result = await handler().execute(
        request(command(category: 'وقود')),
      );

      expect((result as PostExpenseFailure).code, 'idempotencyConflict');
      expect(gateway.calls, 0);
    });

    test('gateway stable failure is retained and mapped without projection',
        () async {
      gateway.response = const ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.authorization,
        code: 'unauthorized.expensePostingDenied',
        retryable: false,
        diagnosticReference: 'diag-safe',
      );

      final result = await handler().execute(request(command()));

      expect((result as PostExpenseFailure).code,
          'unauthorized.expensePostingDenied');
      expect(result.diagnosticReference, 'diag-safe');
      expect(attempts.lastState, ExpensePostingAttemptState.rejected);
      expect(projection.calls, 0);
    });

    test('projection failure stays financially confirmed and repairs locally',
        () async {
      projection.error = StateError('disk full');
      final first = await handler().execute(request(command()));

      expect(first, isA<PostExpenseSuccess>());
      expect((first as PostExpenseSuccess).projectionPending, isTrue);
      expect(first.projectionErrorCode, 'projectionFailure');
      expect(attempts.lastState,
          ExpensePostingAttemptState.confirmedProjectionPending);
      expect(gateway.calls, 1);

      projection.error = null;
      final repaired = await handler().execute(request(command()));

      expect(repaired, isA<PostExpenseSuccess>());
      expect((repaired as PostExpenseSuccess).projectionPending, isFalse);
      expect(gateway.calls, 1,
          reason: 'projection repair must not submit another financial post');
      expect(projection.calls, 2);
      expect(attempts.lastState, ExpensePostingAttemptState.confirmed);
    });
  });
}

ExpensePostingGatewaySuccess _success(
  String commandId,
  String businessId, {
  bool replayed = false,
}) =>
    ExpensePostingGatewaySuccess(
      commandId: commandId,
      businessId: businessId,
      expenseId: '55555555-5555-4555-8555-555555555555',
      financialEntryId: '66666666-6666-4666-8666-666666666666',
      auditEventIds: const [
        '77777777-7777-4777-8777-777777777777',
        '88888888-8888-4888-8888-888888888888',
      ],
      serverAcceptedAtUtc: DateTime.utc(2026, 8, 23, 10),
      businessDate: '2026-08-23',
      amountQirsh: 1250,
      balanceAfterQirsh: 8750,
      replayed: replayed,
    );

final class _AttemptStoreSpy implements ExpensePostingAttemptStore {
  ExpensePostingAttempt? stored;
  final List<String> events = [];

  ExpensePostingAttemptState? get lastState => stored?.state;

  @override
  Future<ExpensePostingAttempt> prepare({
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
        throw const ExpensePostingAttemptConflictException();
      }
      return existing;
    }
    return stored = ExpensePostingAttempt(
      commandId: commandId,
      businessId: businessId,
      canonicalPayloadJson: canonicalPayloadJson,
      localFingerprint: localFingerprint,
      state: ExpensePostingAttemptState.queued,
      createdAtUtc: DateTime.utc(2026, 8, 23),
      updatedAtUtc: DateTime.utc(2026, 8, 23),
    );
  }

  @override
  Future<ExpensePostingAttempt?> load(String commandId) async =>
      stored?.commandId == commandId ? stored : null;

  @override
  Future<void> markSending(String commandId) async {
    events.add('sending');
    stored = stored!.copyWith(
      state: ExpensePostingAttemptState.sending,
      attemptCount: stored!.attemptCount + 1,
    );
  }

  @override
  Future<void> markServerConfirmed(
    String commandId,
    String canonicalServerResultJson,
  ) async {
    events.add('serverConfirmed');
    stored = stored!.copyWith(
      state: ExpensePostingAttemptState.confirmedProjectionPending,
      canonicalServerResultJson: canonicalServerResultJson,
    );
  }

  @override
  Future<void> markConfirmed(String commandId) async {
    events.add('confirmed');
    stored = stored!.copyWith(state: ExpensePostingAttemptState.confirmed);
  }

  @override
  Future<void> markFailure(
    String commandId, {
    required ExpensePostingAttemptState state,
    required String errorCode,
  }) async {
    events.add(state.name);
    stored = stored!.copyWith(state: state, lastErrorCode: errorCode);
  }
}

final class _GatewaySpy implements ExpensePostingGateway {
  _GatewaySpy(this.response);

  ExpensePostingGatewayResponse response;
  int calls = 0;
  final List<String> commandIds = [];
  final List<Map<String, Object?>> payloads = [];

  @override
  Future<ExpensePostingGatewayResponse> post(
    ExpensePostingRequestPayload payload,
  ) async {
    calls++;
    commandIds.add(payload.commandId);
    payloads.add(payload.toCanonicalMap());
    return response;
  }
}

final class _ProjectionSpy implements ConfirmedExpenseProjectionWriter {
  int calls = 0;
  Object? error;

  @override
  Future<void> project(ConfirmedExpenseProjection value) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
  }
}
