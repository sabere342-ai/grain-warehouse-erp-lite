import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

abstract class NegativeBalanceApprovalRequestRepository {
  Future<NegativeBalanceApprovalRequest> createRequest(
    NegativeBalanceApprovalRequestDraft draft,
  );

  Future<NegativeBalanceApprovalRequest?> findById(String requestId);

  Future<List<NegativeBalanceApprovalRequest>> listAll();

  Future<List<NegativeBalanceApprovalRequestTransition>> listTransitions({
    String? requestId,
  });

  Future<NegativeBalanceApprovalRequest> resolveRequest({
    required String requestId,
    required NegativeBalanceApprovalRequestStatus status,
    required String resolverActorId,
    required String reason,
    String? ownerVerificationReference,
    String? resultDocumentId,
  });
}

abstract class DurableNegativeBalanceApprovalRequestRepository
    implements
        NegativeBalanceApprovalRequestRepository,
        TransactionSnapshotProvider {
  Future<void> restoreIntoEmpty({
    required List<NegativeBalanceApprovalRequest> requests,
    required List<NegativeBalanceApprovalRequestTransition> transitions,
  });

  Future<void> clearForOwnerDataWipe();
}

class LocalNegativeBalanceApprovalRequestRepository
    implements DurableNegativeBalanceApprovalRequestRepository {
  LocalNegativeBalanceApprovalRequestRepository({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<NegativeBalanceApprovalRequest> _requests = [];
  final List<NegativeBalanceApprovalRequestTransition> _transitions = [];
  int _requestCounter = 0;
  int _transitionCounter = 0;

  @override
  Future<NegativeBalanceApprovalRequest> createRequest(
    NegativeBalanceApprovalRequestDraft draft,
  ) async {
    _validateDraft(draft);
    final key = draft.idempotencyKey.trim();
    for (final existing in _requests) {
      if (existing.idempotencyKey != key) continue;
      if (_matchesDraft(existing, draft)) return existing;
      throw StateError('Idempotency key payload does not match.');
    }

    final signature = _pendingSignature(draft);
    if (_requests.any((value) =>
        value.status == NegativeBalanceApprovalRequestStatus.pending &&
        value.pendingSignature == signature)) {
      throw StateError(
          'An equivalent pending approval request already exists.');
    }

    final now = _now();
    final request = NegativeBalanceApprovalRequest(
      id: _nextRequestId(now),
      idempotencyKey: key,
      operationType: draft.operationType,
      status: NegativeBalanceApprovalRequestStatus.pending,
      financialAccountId: draft.financialAccountId.trim(),
      paymentMethod: draft.paymentMethod,
      amountQirsh: draft.amountQirsh,
      sourceDocumentId: draft.sourceDocumentId.trim(),
      payloadJson: draft.payloadJson,
      payloadFingerprint: draft.payloadFingerprint.trim(),
      relatedPartyId: _optional(draft.relatedPartyId),
      requesterActorId: draft.requesterActorId.trim(),
      requestedAt: now,
      balanceAtRequestQirsh: draft.balanceAtRequestQirsh,
      expectedBalanceAtRequestQirsh: draft.expectedBalanceAtRequestQirsh,
      deficitAtRequestQirsh: draft.deficitAtRequestQirsh,
      reason: draft.reason.trim(),
    );
    final transition = NegativeBalanceApprovalRequestTransition(
      id: _nextTransitionId(now),
      requestId: request.id,
      toStatus: NegativeBalanceApprovalRequestStatus.pending,
      actorId: request.requesterActorId,
      occurredAt: now,
      reason: request.reason,
    );
    _requests.add(request);
    _transitions.add(transition);
    return request;
  }

  @override
  Future<NegativeBalanceApprovalRequest?> findById(String requestId) async {
    final id = requestId.trim();
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  @override
  Future<List<NegativeBalanceApprovalRequest>> listAll() async {
    final values = [..._requests]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return List.unmodifiable(values);
  }

  @override
  Future<List<NegativeBalanceApprovalRequestTransition>> listTransitions({
    String? requestId,
  }) async {
    final id = _optional(requestId);
    final values = _transitions
        .where((value) => id == null || value.requestId == id)
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return List.unmodifiable(values);
  }

  @override
  Future<NegativeBalanceApprovalRequest> resolveRequest({
    required String requestId,
    required NegativeBalanceApprovalRequestStatus status,
    required String resolverActorId,
    required String reason,
    String? ownerVerificationReference,
    String? resultDocumentId,
  }) async {
    final index = _requests.indexWhere((value) => value.id == requestId.trim());
    if (index < 0) throw StateError('Approval request does not exist.');
    final current = _requests[index];
    final now = _now();
    final resolved = current.resolve(
      status: status,
      resolverActorId: resolverActorId,
      resolvedAt: now,
      resolutionReason: reason,
      ownerVerificationReference: ownerVerificationReference,
      resultDocumentId: resultDocumentId,
    );
    _requests[index] = resolved;
    _transitions.add(NegativeBalanceApprovalRequestTransition(
      id: _nextTransitionId(now),
      requestId: resolved.id,
      fromStatus: current.status,
      toStatus: resolved.status,
      actorId: resolverActorId.trim(),
      occurredAt: now,
      reason: reason.trim(),
    ));
    return resolved;
  }

  @override
  Future<void> restoreIntoEmpty({
    required List<NegativeBalanceApprovalRequest> requests,
    required List<NegativeBalanceApprovalRequestTransition> transitions,
  }) async {
    if (_requests.isNotEmpty || _transitions.isNotEmpty) {
      throw StateError('Approval request repository is not empty.');
    }
    _validateRestored(requests, transitions);
    _requests.addAll(requests);
    _transitions.addAll(transitions);
    _requestCounter = _maxSequence(requests.map((value) => value.id));
    _transitionCounter = _maxSequence(transitions.map((value) => value.id));
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _requests.clear();
    _transitions.clear();
    _requestCounter = 0;
    _transitionCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() => ObjectStateSnapshot<
          (
            List<NegativeBalanceApprovalRequest>,
            List<NegativeBalanceApprovalRequestTransition>,
            int,
            int
          )>(
        captureState: () => (
          List.of(_requests),
          List.of(_transitions),
          _requestCounter,
          _transitionCounter,
        ),
        restoreState: (state) {
          _requests
            ..clear()
            ..addAll(state.$1);
          _transitions
            ..clear()
            ..addAll(state.$2);
          _requestCounter = state.$3;
          _transitionCounter = state.$4;
        },
      );

  void _validateDraft(NegativeBalanceApprovalRequestDraft draft) {
    if (draft.idempotencyKey.trim().isEmpty ||
        draft.financialAccountId.trim().isEmpty ||
        draft.sourceDocumentId.trim().isEmpty ||
        draft.payloadJson.trim().isEmpty ||
        draft.payloadFingerprint.trim().isEmpty ||
        draft.requesterActorId.trim().isEmpty ||
        draft.reason.trim().isEmpty ||
        draft.amountQirsh <= 0 ||
        draft.expectedBalanceAtRequestQirsh >= 0 ||
        draft.deficitAtRequestQirsh != -draft.expectedBalanceAtRequestQirsh ||
        draft.expectedBalanceAtRequestQirsh !=
            draft.balanceAtRequestQirsh - draft.amountQirsh) {
      throw ArgumentError('Invalid negative-balance approval request draft.');
    }
  }

  bool _matchesDraft(
    NegativeBalanceApprovalRequest value,
    NegativeBalanceApprovalRequestDraft draft,
  ) =>
      value.operationType == draft.operationType &&
      value.financialAccountId == draft.financialAccountId.trim() &&
      value.paymentMethod == draft.paymentMethod &&
      value.amountQirsh == draft.amountQirsh &&
      value.sourceDocumentId == draft.sourceDocumentId.trim() &&
      value.payloadFingerprint == draft.payloadFingerprint.trim() &&
      value.requesterActorId == draft.requesterActorId.trim();

  String _pendingSignature(NegativeBalanceApprovalRequestDraft draft) => [
        draft.operationType.name,
        draft.sourceDocumentId.trim(),
        draft.financialAccountId.trim(),
        draft.paymentMethod.name,
        draft.amountQirsh,
        draft.payloadFingerprint.trim(),
      ].join('|');

  void _validateRestored(
    List<NegativeBalanceApprovalRequest> requests,
    List<NegativeBalanceApprovalRequestTransition> transitions,
  ) {
    final ids = <String>{};
    final keys = <String>{};
    final pending = <String>{};
    for (final request in requests) {
      if (!ids.add(request.id) || !keys.add(request.idempotencyKey)) {
        throw StateError('Duplicate approval request identity.');
      }
      if (request.status == NegativeBalanceApprovalRequestStatus.pending &&
          !pending.add(request.pendingSignature)) {
        throw StateError('Duplicate pending approval request.');
      }
    }
    final transitionIds = <String>{};
    for (final transition in transitions) {
      if (!transitionIds.add(transition.id) ||
          !ids.contains(transition.requestId)) {
        throw StateError('Invalid approval request transition.');
      }
    }
  }

  int _maxSequence(Iterable<String> ids) {
    var result = 0;
    for (final id in ids) {
      final value = int.tryParse(id.split('-').last) ?? 0;
      if (value > result) result = value;
    }
    return result;
  }

  String _nextRequestId(DateTime now) =>
      'nbr-${now.microsecondsSinceEpoch}-${++_requestCounter}';
  String _nextTransitionId(DateTime now) =>
      'nbt-${now.microsecondsSinceEpoch}-${++_transitionCounter}';
  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class DriftNegativeBalanceApprovalRequestRepository
    implements DurableNegativeBalanceApprovalRequestRepository {
  DriftNegativeBalanceApprovalRequestRepository(this._database);

  final db.FoundationDatabase _database;
  static const _requestSequence = 'negative_balance_approval_requests';
  static const _transitionSequence =
      'negative_balance_approval_request_transitions';

  @override
  Future<NegativeBalanceApprovalRequest> createRequest(
    NegativeBalanceApprovalRequestDraft draft,
  ) =>
      _database.inTransaction(() async {
        final existing =
            await (_database.select(_database.negativeBalanceApprovalRequests)
                  ..where((row) => row.idempotencyKey.equals(
                        draft.idempotencyKey.trim(),
                      )))
                .getSingleOrNull();
        if (existing != null) {
          final value = _requestFromRow(existing);
          if (value.operationType == draft.operationType &&
              value.financialAccountId == draft.financialAccountId.trim() &&
              value.paymentMethod == draft.paymentMethod &&
              value.amountQirsh == draft.amountQirsh &&
              value.sourceDocumentId == draft.sourceDocumentId.trim() &&
              value.payloadFingerprint == draft.payloadFingerprint.trim() &&
              value.requesterActorId == draft.requesterActorId.trim()) {
            return value;
          }
          throw StateError('Idempotency key payload does not match.');
        }

        final now = DateTime.now();
        final request = NegativeBalanceApprovalRequest(
          id: await _nextId(_requestSequence, 'nbr', now),
          idempotencyKey: draft.idempotencyKey.trim(),
          operationType: draft.operationType,
          status: NegativeBalanceApprovalRequestStatus.pending,
          financialAccountId: draft.financialAccountId.trim(),
          paymentMethod: draft.paymentMethod,
          amountQirsh: draft.amountQirsh,
          sourceDocumentId: draft.sourceDocumentId.trim(),
          payloadJson: draft.payloadJson,
          payloadFingerprint: draft.payloadFingerprint.trim(),
          relatedPartyId: _optional(draft.relatedPartyId),
          requesterActorId: draft.requesterActorId.trim(),
          requestedAt: now,
          balanceAtRequestQirsh: draft.balanceAtRequestQirsh,
          expectedBalanceAtRequestQirsh: draft.expectedBalanceAtRequestQirsh,
          deficitAtRequestQirsh: draft.deficitAtRequestQirsh,
          reason: draft.reason.trim(),
        );
        final transition = NegativeBalanceApprovalRequestTransition(
          id: await _nextId(_transitionSequence, 'nbt', now),
          requestId: request.id,
          toStatus: NegativeBalanceApprovalRequestStatus.pending,
          actorId: request.requesterActorId,
          occurredAt: now,
          reason: request.reason,
        );
        await _database
            .into(_database.negativeBalanceApprovalRequests)
            .insert(_requestCompanion(request));
        await _database
            .into(_database.negativeBalanceApprovalRequestTransitions)
            .insert(_transitionCompanion(transition));
        return request;
      });

  @override
  Future<NegativeBalanceApprovalRequest?> findById(String requestId) async {
    final row =
        await (_database.select(_database.negativeBalanceApprovalRequests)
              ..where((value) => value.id.equals(requestId.trim())))
            .getSingleOrNull();
    return row == null ? null : _requestFromRow(row);
  }

  @override
  Future<List<NegativeBalanceApprovalRequest>> listAll() async {
    final query = _database.select(_database.negativeBalanceApprovalRequests)
      ..orderBy([(row) => OrderingTerm.desc(row.requestedAt)]);
    return (await query.get()).map(_requestFromRow).toList(growable: false);
  }

  @override
  Future<List<NegativeBalanceApprovalRequestTransition>> listTransitions({
    String? requestId,
  }) async {
    final query = _database.select(
      _database.negativeBalanceApprovalRequestTransitions,
    );
    final id = _optional(requestId);
    if (id != null) query.where((row) => row.requestId.equals(id));
    query.orderBy([(row) => OrderingTerm.asc(row.occurredAt)]);
    return (await query.get()).map(_transitionFromRow).toList(growable: false);
  }

  @override
  Future<NegativeBalanceApprovalRequest> resolveRequest({
    required String requestId,
    required NegativeBalanceApprovalRequestStatus status,
    required String resolverActorId,
    required String reason,
    String? ownerVerificationReference,
    String? resultDocumentId,
  }) =>
      _database.inTransaction(() async {
        final current = await findById(requestId);
        if (current == null) {
          throw StateError('Approval request does not exist.');
        }
        final now = DateTime.now();
        final resolved = current.resolve(
          status: status,
          resolverActorId: resolverActorId,
          resolvedAt: now,
          resolutionReason: reason,
          ownerVerificationReference: ownerVerificationReference,
          resultDocumentId: resultDocumentId,
        );
        await (_database.update(_database.negativeBalanceApprovalRequests)
              ..where((row) => row.id.equals(current.id)))
            .write(_requestCompanion(resolved));
        final transition = NegativeBalanceApprovalRequestTransition(
          id: await _nextId(_transitionSequence, 'nbt', now),
          requestId: current.id,
          fromStatus: current.status,
          toStatus: status,
          actorId: resolverActorId.trim(),
          occurredAt: now,
          reason: reason.trim(),
        );
        await _database
            .into(_database.negativeBalanceApprovalRequestTransitions)
            .insert(_transitionCompanion(transition));
        return resolved;
      });

  @override
  Future<void> restoreIntoEmpty({
    required List<NegativeBalanceApprovalRequest> requests,
    required List<NegativeBalanceApprovalRequestTransition> transitions,
  }) =>
      _database.inTransaction(() async {
        if (await _database.negativeBalanceApprovalRequests
                    .count()
                    .getSingle() !=
                0 ||
            await _database.negativeBalanceApprovalRequestTransitions
                    .count()
                    .getSingle() !=
                0) {
          throw StateError('Approval request repository is not empty.');
        }
        final validator = LocalNegativeBalanceApprovalRequestRepository();
        await validator.restoreIntoEmpty(
          requests: requests,
          transitions: transitions,
        );
        for (final request in requests) {
          await _database
              .into(_database.negativeBalanceApprovalRequests)
              .insert(_requestCompanion(request));
        }
        for (final transition in transitions) {
          await _database
              .into(_database.negativeBalanceApprovalRequestTransitions)
              .insert(_transitionCompanion(transition));
        }
        await _setNextSequence(
          _requestSequence,
          _maxSequence(requests.map((value) => value.id)) + 1,
        );
        await _setNextSequence(
          _transitionSequence,
          _maxSequence(transitions.map((value) => value.id)) + 1,
        );
      });

  @override
  Future<void> clearForOwnerDataWipe() => _database.inTransaction(() async {
        await _database
            .delete(_database.negativeBalanceApprovalRequestTransitions)
            .go();
        await _database.delete(_database.negativeBalanceApprovalRequests).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.isIn([
                    _requestSequence,
                    _transitionSequence,
                  ])))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _DriftNegativeBalanceRequestSnapshot(this);

  Future<String> _nextId(String sequence, String prefix, DateTime now) async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((value) => value.repository.equals(sequence)))
        .getSingleOrNull();
    final next = row?.nextValue ?? 1;
    await _setNextSequence(sequence, next + 1);
    return '$prefix-${now.microsecondsSinceEpoch}-$next';
  }

  Future<void> _setNextSequence(String sequence, int next) =>
      _database.repositorySequences.insertOnConflictUpdate(
        db.RepositorySequencesCompanion.insert(
          repository: sequence,
          nextValue: next,
        ),
      );

  int _maxSequence(Iterable<String> ids) {
    var result = 0;
    for (final id in ids) {
      final value = int.tryParse(id.split('-').last) ?? 0;
      if (value > result) result = value;
    }
    return result;
  }

  db.NegativeBalanceApprovalRequestsCompanion _requestCompanion(
    NegativeBalanceApprovalRequest value,
  ) =>
      db.NegativeBalanceApprovalRequestsCompanion(
        id: Value(value.id),
        idempotencyKey: Value(value.idempotencyKey),
        operationType: Value(value.operationType.name),
        status: Value(value.status.name),
        financialAccountId: Value(value.financialAccountId),
        paymentMethod: Value(value.paymentMethod.name),
        amountQirsh: Value(value.amountQirsh),
        sourceDocumentId: Value(value.sourceDocumentId),
        payloadJson: Value(value.payloadJson),
        payloadFingerprint: Value(value.payloadFingerprint),
        relatedPartyId: Value(value.relatedPartyId),
        requesterActorId: Value(value.requesterActorId),
        requestedAt: Value(value.requestedAt),
        balanceAtRequestQirsh: Value(value.balanceAtRequestQirsh),
        expectedBalanceAtRequestQirsh:
            Value(value.expectedBalanceAtRequestQirsh),
        deficitAtRequestQirsh: Value(value.deficitAtRequestQirsh),
        reason: Value(value.reason),
        resolverActorId: Value(value.resolverActorId),
        resolvedAt: Value(value.resolvedAt),
        resolutionReason: Value(value.resolutionReason),
        ownerVerificationReference: Value(value.ownerVerificationReference),
        resultDocumentId: Value(value.resultDocumentId),
        recordVersion: Value(value.recordVersion),
      );

  db.NegativeBalanceApprovalRequestTransitionsCompanion _transitionCompanion(
    NegativeBalanceApprovalRequestTransition value,
  ) =>
      db.NegativeBalanceApprovalRequestTransitionsCompanion(
        id: Value(value.id),
        requestId: Value(value.requestId),
        fromStatus: Value(value.fromStatus?.name),
        toStatus: Value(value.toStatus.name),
        actorId: Value(value.actorId),
        occurredAt: Value(value.occurredAt),
        reason: Value(value.reason),
      );

  NegativeBalanceApprovalRequest _requestFromRow(
    db.NegativeBalanceApprovalRequest row,
  ) =>
      NegativeBalanceApprovalRequest(
        id: row.id,
        idempotencyKey: row.idempotencyKey,
        operationType: _enumValue(
          NegativeBalanceApprovalRequestOperationType.values,
          row.operationType,
        ),
        status: _enumValue(
          NegativeBalanceApprovalRequestStatus.values,
          row.status,
        ),
        financialAccountId: row.financialAccountId,
        paymentMethod: _enumValue(PaymentMethod.values, row.paymentMethod),
        amountQirsh: row.amountQirsh,
        sourceDocumentId: row.sourceDocumentId,
        payloadJson: row.payloadJson,
        payloadFingerprint: row.payloadFingerprint,
        relatedPartyId: row.relatedPartyId,
        requesterActorId: row.requesterActorId,
        requestedAt: row.requestedAt,
        balanceAtRequestQirsh: row.balanceAtRequestQirsh,
        expectedBalanceAtRequestQirsh: row.expectedBalanceAtRequestQirsh,
        deficitAtRequestQirsh: row.deficitAtRequestQirsh,
        reason: row.reason,
        resolverActorId: row.resolverActorId,
        resolvedAt: row.resolvedAt,
        resolutionReason: row.resolutionReason,
        ownerVerificationReference: row.ownerVerificationReference,
        resultDocumentId: row.resultDocumentId,
        recordVersion: row.recordVersion,
      );

  NegativeBalanceApprovalRequestTransition _transitionFromRow(
    db.NegativeBalanceApprovalRequestTransition row,
  ) =>
      NegativeBalanceApprovalRequestTransition(
        id: row.id,
        requestId: row.requestId,
        fromStatus: row.fromStatus == null
            ? null
            : _enumValue(
                NegativeBalanceApprovalRequestStatus.values,
                row.fromStatus!,
              ),
        toStatus: _enumValue(
          NegativeBalanceApprovalRequestStatus.values,
          row.toStatus,
        ),
        actorId: row.actorId,
        occurredAt: row.occurredAt,
        reason: row.reason,
      );

  T _enumValue<T extends Enum>(List<T> values, String name) =>
      values.firstWhere(
        (value) => value.name == name,
        orElse: () => throw FormatException('Unknown enum value: $name'),
      );

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _DriftNegativeBalanceRequestSnapshot extends SnapshotHolder {
  _DriftNegativeBalanceRequestSnapshot(this.repository);

  final DriftNegativeBalanceApprovalRequestRepository repository;
  List<NegativeBalanceApprovalRequest>? requests;
  List<NegativeBalanceApprovalRequestTransition>? transitions;

  @override
  Future<void> capture() async {
    requests = await repository.listAll();
    transitions = await repository.listTransitions();
  }

  @override
  Future<void> rollback() async {
    final savedRequests = requests;
    final savedTransitions = transitions;
    if (savedRequests == null || savedTransitions == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreIntoEmpty(
      requests: savedRequests,
      transitions: savedTransitions,
    );
  }
}
