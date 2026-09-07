import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

enum ConfirmedInternalTransferProjectionStage {
  afterHeader,
  afterSourceEntry,
  afterDestinationEntry,
  afterAudits,
  afterBalances,
}

final class DriftConfirmedInternalTransferProjectionWriter
    implements ConfirmedInternalTransferProjectionWriter {
  DriftConfirmedInternalTransferProjectionWriter(
    this._database, {
    required DriftFinancialAccountRepository financialAccountRepository,
    FutureOr<void> Function(ConfirmedInternalTransferProjectionStage stage)?
        failureInjector,
  })  : _financialAccountRepository = financialAccountRepository,
        _failureInjector = failureInjector;

  final db.FoundationDatabase _database;
  final DriftFinancialAccountRepository _financialAccountRepository;
  final FutureOr<void> Function(ConfirmedInternalTransferProjectionStage stage)?
      _failureInjector;

  @override
  Future<void> project(ConfirmedInternalTransferProjection value) async {
    if (value.sourceServerAccountId == value.destinationServerAccountId ||
        value.sourceEntryId == value.destinationEntryId ||
        value.auditEventIds.length != 3 ||
        value.auditEventIds.toSet().length != 3) {
      throw StateError('Invalid authoritative transfer projection envelope.');
    }
    await _financialAccountRepository.applySerializedExternalProjection(
      () => _database.inTransaction(() => _projectTransaction(value)),
    );
  }

  Future<void> _projectTransaction(
    ConfirmedInternalTransferProjection value,
  ) async {
    final attempt =
        await (_database.select(_database.internalTransferPostingAttempts)
              ..where((table) => table.commandId.equals(value.commandId)))
            .getSingleOrNull();
    if (attempt == null ||
        attempt.businessId != value.businessId ||
        attempt.localFingerprint != value.localFingerprint) {
      throw StateError('Matching transfer attempt is required.');
    }
    final alreadyConfirmed = attempt.lifecycleState ==
        InternalTransferPostingAttemptState.confirmed.name;
    final links = await (_database.select(_database.financialAccountCloudLinks)
          ..where((table) =>
              table.businessId.equals(value.businessId) &
              table.serverAccountUuid.isIn(<String>[
                value.sourceServerAccountId,
                value.destinationServerAccountId,
              ])))
        .get();
    if (links.length != 2) {
      throw StateError('Both Cloud-ready account links are required.');
    }
    final sourceLink = links.singleWhere(
      (link) => link.serverAccountUuid == value.sourceServerAccountId,
    );
    final destinationLink = links.singleWhere(
      (link) => link.serverAccountUuid == value.destinationServerAccountId,
    );
    if (sourceLink.localAccountId == destinationLink.localAccountId) {
      throw StateError('Transfer account links must be distinct.');
    }

    final existingByCommand =
        await (_database.select(_database.financialTransfers)
              ..where((table) => table.clientRequestId.equals(value.commandId)))
            .getSingleOrNull();
    if (existingByCommand != null && existingByCommand.id != value.transferId) {
      throw StateError(
          'Projected command conflicts with an existing transfer.');
    }
    final existing = await (_database.select(_database.financialTransfers)
          ..where((table) => table.id.equals(value.transferId)))
        .getSingleOrNull();
    if (existing == null) {
      await _database.into(_database.financialTransfers).insert(
            db.FinancialTransfersCompanion.insert(
              id: value.transferId,
              displayNumber: value.displayNumber,
              clientRequestId: value.commandId,
              transferReference: value.transferReference,
              sourceAccountId: sourceLink.localAccountId,
              destinationAccountId: destinationLink.localAccountId,
              amountQirsh: value.amountQirsh,
              effectiveDate: _date(value.effectiveBusinessDate),
              createdAt: value.serverAcceptedAtUtc,
              createdByUserId: value.actorAuthUserId,
              sourceEntryId: value.sourceEntryId,
              destinationEntryId: value.destinationEntryId,
              note: Value(value.note),
            ),
          );
    } else {
      _require(existing.displayNumber == value.displayNumber &&
          existing.clientRequestId == value.commandId &&
          existing.transferReference == value.transferReference &&
          existing.sourceAccountId == sourceLink.localAccountId &&
          existing.destinationAccountId == destinationLink.localAccountId &&
          existing.amountQirsh == value.amountQirsh &&
          existing.effectiveDate == _date(value.effectiveBusinessDate) &&
          existing.createdAt.millisecondsSinceEpoch ==
              value.serverAcceptedAtUtc.millisecondsSinceEpoch &&
          existing.createdByUserId == value.actorAuthUserId &&
          existing.sourceEntryId == value.sourceEntryId &&
          existing.destinationEntryId == value.destinationEntryId &&
          existing.note == value.note &&
          existing.negativeBalanceApprovalId == null &&
          existing.originalTransferId == null &&
          existing.reversalTransferId == null);
    }
    await _failureInjector?.call(
      ConfirmedInternalTransferProjectionStage.afterHeader,
    );

    await _projectEntry(
      id: value.sourceEntryId,
      localAccountId: sourceLink.localAccountId,
      direction: 'outflow',
      sourceType: 'transferOut',
      value: value,
    );
    await _failureInjector?.call(
      ConfirmedInternalTransferProjectionStage.afterSourceEntry,
    );
    await _projectEntry(
      id: value.destinationEntryId,
      localAccountId: destinationLink.localAccountId,
      direction: 'inflow',
      sourceType: 'transferIn',
      value: value,
    );
    await _failureInjector?.call(
      ConfirmedInternalTransferProjectionStage.afterDestinationEntry,
    );

    await _projectAudit(
      id: value.auditEventIds[0],
      actionType: 'financial_account.entry.created',
      referenceId: value.sourceEntryId,
      descriptionAr: 'تم اعتماد حركة التحويل الخارجة من الخادم.',
      value: value,
    );
    await _projectAudit(
      id: value.auditEventIds[1],
      actionType: 'financial_account.entry.created',
      referenceId: value.destinationEntryId,
      descriptionAr: 'تم اعتماد حركة التحويل الداخلة من الخادم.',
      value: value,
    );
    await _projectAudit(
      id: value.auditEventIds[2],
      actionType: 'financial_transfer.created',
      referenceId: value.transferId,
      descriptionAr: 'تم اعتماد التحويل المالي من الخادم.',
      value: value,
    );
    await _failureInjector?.call(
      ConfirmedInternalTransferProjectionStage.afterAudits,
    );

    final sourceBalance = await _balance(sourceLink.localAccountId);
    final destinationBalance = await _balance(destinationLink.localAccountId);
    if (sourceBalance != value.sourceBalanceAfterQirsh ||
        destinationBalance != value.destinationBalanceAfterQirsh) {
      throw StateError('Projected account balances do not match the server.');
    }
    await _failureInjector?.call(
      ConfirmedInternalTransferProjectionStage.afterBalances,
    );
    if (alreadyConfirmed) return;
    await _updateLink(
      sourceLink,
      value.sourceBalanceAfterQirsh,
      value.serverAcceptedAtUtc,
    );
    await _updateLink(
      destinationLink,
      value.destinationBalanceAfterQirsh,
      value.serverAcceptedAtUtc,
    );
    await (_database.update(_database.internalTransferPostingAttempts)
          ..where((table) => table.commandId.equals(value.commandId)))
        .write(
      db.InternalTransferPostingAttemptsCompanion(
        lifecycleState:
            Value(InternalTransferPostingAttemptState.confirmed.name),
        updatedAtUtc: Value(DateTime.now().toUtc()),
        lastErrorCode: const Value(null),
      ),
    );
  }

  Future<void> _projectEntry({
    required String id,
    required String localAccountId,
    required String direction,
    required String sourceType,
    required ConfirmedInternalTransferProjection value,
  }) async {
    final existing = await (_database.select(_database.financialAccountEntries)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      await _database.into(_database.financialAccountEntries).insert(
            db.FinancialAccountEntriesCompanion.insert(
              id: id,
              accountId: localAccountId,
              direction: direction,
              amountQirsh: value.amountQirsh,
              sourceType: sourceType,
              sourceDocumentId: value.transferId,
              sourceDocumentNumber: Value(value.displayNumber),
              effectiveDate: _date(value.effectiveBusinessDate),
              createdAt: value.serverAcceptedAtUtc,
              createdByUserId: value.actorAuthUserId,
              reference: Value(value.transferReference),
              note: Value(value.note),
            ),
          );
      return;
    }
    _require(existing.accountId == localAccountId &&
        existing.direction == direction &&
        existing.amountQirsh == value.amountQirsh &&
        existing.sourceType == sourceType &&
        existing.sourceDocumentId == value.transferId &&
        existing.sourceDocumentNumber == value.displayNumber &&
        existing.effectiveDate == _date(value.effectiveBusinessDate) &&
        existing.createdAt.millisecondsSinceEpoch ==
            value.serverAcceptedAtUtc.millisecondsSinceEpoch &&
        existing.createdByUserId == value.actorAuthUserId &&
        existing.reference == value.transferReference &&
        existing.note == value.note &&
        existing.reversalOf == null &&
        existing.negativeBalanceApprovalId == null);
  }

  Future<void> _projectAudit({
    required String id,
    required String actionType,
    required String referenceId,
    required String descriptionAr,
    required ConfirmedInternalTransferProjection value,
  }) async {
    final metadata = _auditMetadata(value);
    final existing = await (_database.select(_database.auditLogs)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) {
      _require(existing.actionType == actionType &&
          existing.referenceId == referenceId &&
          existing.timestamp.millisecondsSinceEpoch ==
              value.serverAcceptedAtUtc.millisecondsSinceEpoch &&
          existing.actorId == value.actorAuthUserId &&
          existing.metadataJson == metadata);
      return;
    }
    await _database.into(_database.auditLogs).insert(
          db.AuditLogsCompanion.insert(
            id: id,
            timestamp: value.serverAcceptedAtUtc,
            actionType: actionType,
            descriptionAr: descriptionAr,
            actorId: Value(value.actorAuthUserId),
            referenceId: Value(referenceId),
            metadataJson: metadata,
          ),
        );
  }

  Future<int> _balance(String localAccountId) async {
    final row = await _database.customSelect(
      'SELECT COALESCE(SUM(CASE WHEN direction = ? THEN amount_qirsh '
      'ELSE -amount_qirsh END), 0) AS balance '
      'FROM financial_account_entries WHERE account_id = ?',
      variables: <Variable<Object>>[
        const Variable<String>('inflow'),
        Variable<String>(localAccountId),
      ],
      readsFrom: {_database.financialAccountEntries},
    ).getSingle();
    return row.read<int>('balance');
  }

  Future<void> _updateLink(
    db.FinancialAccountCloudLinkRow link,
    int balance,
    DateTime acceptedAt,
  ) =>
      (_database.update(_database.financialAccountCloudLinks)
            ..where(
                (table) => table.localAccountId.equals(link.localAccountId)))
          .write(
        db.FinancialAccountCloudLinksCompanion(
          reconciledServerBalanceQirsh: Value(balance),
          reconciledAtUtc: Value(acceptedAt),
          reconciliationVersion: Value(link.reconciliationVersion + 1),
        ),
      );

  String _auditMetadata(ConfirmedInternalTransferProjection value) =>
      jsonEncode(<String, Object?>{
        'amountQirsh': value.amountQirsh,
        'businessId': value.businessId,
        'commandId': value.commandId,
        'destinationFinancialAccountId': value.destinationServerAccountId,
        'destinationFinancialEntryId': value.destinationEntryId,
        'displayNumber': value.displayNumber,
        'effectiveBusinessDate': value.effectiveBusinessDate,
        'serverAcceptedAtUtc': value.serverAcceptedAtUtc.toIso8601String(),
        'sourceFinancialAccountId': value.sourceServerAccountId,
        'sourceFinancialEntryId': value.sourceEntryId,
        'transferId': value.transferId,
        'transferReference': value.transferReference,
      });

  DateTime _date(String value) {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return DateTime(parts[0], parts[1], parts[2]);
  }

  void _require(bool condition) {
    if (!condition) throw StateError('Conflicting acknowledged projection.');
  }
}
