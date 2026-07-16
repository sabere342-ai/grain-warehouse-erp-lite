import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';

class DriftFinancialAccountRepository extends LocalFinancialAccountRepository {
  DriftFinancialAccountRepository._(this.database,
      {super.auditLogRepository, super.negativeBalanceApprovalService});

  final FoundationDatabase database;
  Future<void> _writeTail = Future<void>.value();

  static Future<DriftFinancialAccountRepository> open(
    FoundationDatabase database, {
    AuditLogRepository? auditLogRepository,
    NegativeBalanceApprovalService? negativeBalanceApprovalService,
  }) async {
    final result = DriftFinancialAccountRepository._(database,
        auditLogRepository: auditLogRepository,
        negativeBalanceApprovalService: negativeBalanceApprovalService);
    await result._hydrate();
    return result;
  }

  Future<T> _write<T>(Future<T> Function() operation) async {
    final completion = Completer<void>();
    final previous = _writeTail;
    _writeTail = completion.future;
    await previous.catchError((_) {});
    final snapshot = super.createTransactionSnapshot();
    await snapshot.capture();
    try {
      final result = await operation();
      await _persist();
      return result;
    } catch (_) {
      await snapshot.rollback();
      rethrow;
    } finally {
      completion.complete();
    }
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _DurableSnapshot(super.createTransactionSnapshot(), _persist);

  @override
  Future<FinancialAccount> createAccount(FinancialAccountDraft draft) =>
      _write(() => super.createAccount(draft));
  @override
  Future<void> deactivateAccount(
          String accountId, String deactivatedByUserId) =>
      _write(() => super.deactivateAccount(accountId, deactivatedByUserId));
  @override
  Future<void> reactivateAccount(
          String accountId, String reactivatedByUserId) =>
      _write(() => super.reactivateAccount(accountId, reactivatedByUserId));
  @override
  Future<void> updateAccountPolicy(
          {required String accountId,
          required bool allowNegativeBalance,
          required String updatedByUserId}) =>
      _write(() => super.updateAccountPolicy(
          accountId: accountId,
          allowNegativeBalance: allowNegativeBalance,
          updatedByUserId: updatedByUserId));
  @override
  Future<void> setOpeningBalance(
          {required String accountId,
          required int amountQirsh,
          required DateTime effectiveDate,
          required String createdByUserId}) =>
      _write(() => super.setOpeningBalance(
          accountId: accountId,
          amountQirsh: amountQirsh,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId));
  @override
  Future<void> correctOpeningBalance(OpeningBalanceCorrectionDraft draft) =>
      _write(() => super.correctOpeningBalance(draft));
  @override
  Future<FinancialAccountEntry> createEntry(
          {required String accountId,
          required FinancialAccountEntryDirection direction,
          required int amountQirsh,
          required FinancialAccountEntrySource sourceType,
          required String sourceDocumentId,
          required DateTime effectiveDate,
          required String createdByUserId,
          String? sourceDocumentNumber,
          String? reference,
          String? note,
          String? reversalOf,
          String? correctionGroup,
          PaymentMethod? paymentMethod,
          String? approvedByUserId,
          String? negativeBalanceApprovalId,
          String? approvalSourceDocumentId,
          NegativeBalanceApprovalContext? approvalAuthorizationContext}) =>
      _write(() => super.createEntry(
          accountId: accountId,
          direction: direction,
          amountQirsh: amountQirsh,
          sourceType: sourceType,
          sourceDocumentId: sourceDocumentId,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId,
          sourceDocumentNumber: sourceDocumentNumber,
          reference: reference,
          note: note,
          reversalOf: reversalOf,
          correctionGroup: correctionGroup,
          paymentMethod: paymentMethod,
          approvedByUserId: approvedByUserId,
          negativeBalanceApprovalId: negativeBalanceApprovalId,
          approvalSourceDocumentId: approvalSourceDocumentId,
          approvalAuthorizationContext: approvalAuthorizationContext));
  @override
  Future<FinancialAccountEntry> createSupplierOverpaymentEntry(
          {required String accountId,
          required int amountQirsh,
          required String sourceDocumentId,
          required DateTime effectiveDate,
          required String createdByUserId,
          required NegativeBalanceApprovalConsumption authorization,
          String? reference,
          String? note,
          PaymentMethod? paymentMethod}) =>
      _write(() => super.createSupplierOverpaymentEntry(
          accountId: accountId,
          amountQirsh: amountQirsh,
          sourceDocumentId: sourceDocumentId,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId,
          authorization: authorization,
          reference: reference,
          note: note,
          paymentMethod: paymentMethod));
  @override
  Future<FinancialAccountEntry> createCustomerAdvanceRefundEntry(
          {required String accountId,
          required String customerId,
          required String advanceId,
          required int amountQirsh,
          required String sourceDocumentId,
          required DateTime effectiveDate,
          required String createdByUserId,
          required NegativeBalanceApprovalConsumption authorization,
          String? reference,
          PaymentMethod? paymentMethod}) =>
      _write(() => super.createCustomerAdvanceRefundEntry(
          accountId: accountId,
          customerId: customerId,
          advanceId: advanceId,
          amountQirsh: amountQirsh,
          sourceDocumentId: sourceDocumentId,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId,
          authorization: authorization,
          reference: reference,
          paymentMethod: paymentMethod));
  @override
  Future<FinancialTransfer> createTransfer(
          {required AppUser user, required FinancialTransferDraft draft}) =>
      _write(() => super.createTransfer(user: user, draft: draft));
  @override
  Future<FinancialTransfer> reverseTransfer(
          {required AppUser user,
          required String transferId,
          required String reason}) =>
      _write(() => super
          .reverseTransfer(user: user, transferId: transferId, reason: reason));
  @override
  Future<FinancialClosing> createClosing(
          {required AppUser user, required FinancialClosingDraft draft}) =>
      _write(() => super.createClosing(user: user, draft: draft));
  @override
  Future<FinancialClosing> reopenClosing(
          {required AppUser user,
          required String closingId,
          required String reason}) =>
      _write(() => super
          .reopenClosing(user: user, closingId: closingId, reason: reason));
  @override
  Future<void> restoreFinancialAccountsIntoEmpty(
          {required List<FinancialAccount> accounts,
          required List<FinancialAccountEntry> entries,
          List<FinancialTransfer> transfers = const [],
          List<FinancialClosing> closings = const []}) =>
      _write(() => super.restoreFinancialAccountsIntoEmpty(
          accounts: accounts,
          entries: entries,
          transfers: transfers,
          closings: closings));
  @override
  Future<void> clearForOwnerDataWipe() => _write(super.clearForOwnerDataWipe);

  Future<void> _hydrate() async {
    final aa = await database.select(database.financialAccounts).get();
    final ee = await database.select(database.financialAccountEntries).get();
    final tt = await database.select(database.financialTransfers).get();
    final cc = await database.select(database.financialClosings).get();
    if (aa.isEmpty && ee.isEmpty && tt.isEmpty && cc.isEmpty) return;
    await super.restoreFinancialAccountsIntoEmpty(
        accounts: aa
            .map((r) => FinancialAccount(
                id: r.id,
                name: r.name,
                type: FinancialAccountType.values.byName(r.type),
                isActive: r.isActive,
                allowNegativeBalance: r.allowNegativeBalance,
                openingBalanceQirsh: r.openingBalanceQirsh,
                openingBalanceDate: r.openingBalanceDate,
                referenceInfo: r.referenceInfo,
                notes: r.notes,
                createdByUserId: r.createdByUserId,
                createdAt: r.createdAt))
            .toList(),
        entries: ee
            .map((r) => FinancialAccountEntry(
                id: r.id,
                accountId: r.accountId,
                direction:
                    FinancialAccountEntryDirection.values.byName(r.direction),
                amountQirsh: r.amountQirsh,
                sourceType:
                    FinancialAccountEntrySource.values.byName(r.sourceType),
                sourceDocumentId: r.sourceDocumentId,
                sourceDocumentNumber: r.sourceDocumentNumber,
                effectiveDate: r.effectiveDate,
                createdAt: r.createdAt,
                createdByUserId: r.createdByUserId,
                reference: r.reference,
                note: r.note,
                reversalOf: r.reversalOf,
                correctionGroup: r.correctionGroup,
                paymentMethod: r.paymentMethod == null
                    ? null
                    : PaymentMethod.values.byName(r.paymentMethod!),
                approvedByUserId: r.approvedByUserId,
                negativeBalanceApprovalId: r.negativeBalanceApprovalId))
            .toList(),
        transfers: tt
            .map((r) => FinancialTransfer(
                id: r.id,
                displayNumber: r.displayNumber,
                clientRequestId: r.clientRequestId,
                transferReference: r.transferReference,
                sourceAccountId: r.sourceAccountId,
                destinationAccountId: r.destinationAccountId,
                amountQirsh: r.amountQirsh,
                effectiveDate: r.effectiveDate,
                createdAt: r.createdAt,
                createdByUserId: r.createdByUserId,
                sourceEntryId: r.sourceEntryId,
                destinationEntryId: r.destinationEntryId,
                note: r.note,
                negativeBalanceApprovalId: r.negativeBalanceApprovalId,
                originalTransferId: r.originalTransferId,
                reversalTransferId: r.reversalTransferId,
                reversalReason: r.reversalReason))
            .toList(),
        closings: cc
            .map((r) => FinancialClosing(
                id: r.id,
                kind: FinancialClosingKind.values.byName(r.kind),
                fromDate: r.fromDate,
                toDate: r.toDate,
                lines: (jsonDecode(r.linesJson) as List).map((v) {
                  final l = v as Map<String, dynamic>;
                  return FinancialClosingLine(
                      accountId: l['accountId'] as String,
                      expectedBalanceQirsh: l['expected'] as int,
                      actualBalanceQirsh: l['actual'] as int);
                }).toList(),
                createdAt: r.createdAt,
                createdByUserId: r.createdByUserId,
                note: r.note,
                reopenedAt: r.reopenedAt,
                reopenedByUserId: r.reopenedByUserId,
                reopenReason: r.reopenReason))
            .toList());
  }

  Future<void> _persist() async {
    final accounts = await listAccounts(includeInactive: true);
    final entries = <FinancialAccountEntry>[];
    for (final a in accounts) {
      entries
          .addAll((await statementForAccount(a.id)).lines.map((l) => l.entry));
    }
    final transfers = await listTransfers();
    final closings = await listClosings();
    await database.inTransaction(() async {
      await database.delete(database.financialClosings).go();
      await database.delete(database.financialTransfers).go();
      await database.delete(database.financialAccountEntries).go();
      await database.delete(database.financialAccounts).go();
      for (final a in accounts) {
        await database.into(database.financialAccounts).insert(
            FinancialAccountsCompanion.insert(
                id: a.id,
                name: a.name,
                type: a.type.name,
                isActive: a.isActive,
                allowNegativeBalance: a.allowNegativeBalance,
                openingBalanceQirsh: a.openingBalanceQirsh,
                openingBalanceDate: Value(a.openingBalanceDate),
                referenceInfo: Value(a.referenceInfo),
                notes: Value(a.notes),
                createdByUserId: a.createdByUserId,
                createdAt: a.createdAt));
      }
      for (final e in entries) {
        await database.into(database.financialAccountEntries).insert(
            FinancialAccountEntriesCompanion.insert(
                id: e.id,
                accountId: e.accountId,
                direction: e.direction.name,
                amountQirsh: e.amountQirsh,
                sourceType: e.sourceType.name,
                sourceDocumentId: e.sourceDocumentId,
                sourceDocumentNumber: Value(e.sourceDocumentNumber),
                effectiveDate: e.effectiveDate,
                createdAt: e.createdAt,
                createdByUserId: e.createdByUserId,
                reference: Value(e.reference),
                note: Value(e.note),
                reversalOf: Value(e.reversalOf),
                correctionGroup: Value(e.correctionGroup),
                paymentMethod: Value(e.paymentMethod?.name),
                approvedByUserId: Value(e.approvedByUserId),
                negativeBalanceApprovalId: Value(e.negativeBalanceApprovalId)));
      }
      for (final t in transfers) {
        await database.into(database.financialTransfers).insert(
            FinancialTransfersCompanion.insert(
                id: t.id,
                displayNumber: t.displayNumber,
                clientRequestId: t.clientRequestId,
                transferReference: t.transferReference,
                sourceAccountId: t.sourceAccountId,
                destinationAccountId: t.destinationAccountId,
                amountQirsh: t.amountQirsh,
                effectiveDate: t.effectiveDate,
                createdAt: t.createdAt,
                createdByUserId: t.createdByUserId,
                sourceEntryId: t.sourceEntryId,
                destinationEntryId: t.destinationEntryId,
                note: Value(t.note),
                negativeBalanceApprovalId: Value(t.negativeBalanceApprovalId),
                originalTransferId: Value(t.originalTransferId),
                reversalTransferId: Value(t.reversalTransferId),
                reversalReason: Value(t.reversalReason)));
      }
      for (final c in closings) {
        await database
            .into(database.financialClosings)
            .insert(FinancialClosingsCompanion.insert(
                id: c.id,
                kind: c.kind.name,
                fromDate: c.fromDate,
                toDate: c.toDate,
                linesJson: jsonEncode(c.lines
                    .map((l) => {
                          'accountId': l.accountId,
                          'expected': l.expectedBalanceQirsh,
                          'actual': l.actualBalanceQirsh
                        })
                    .toList()),
                createdAt: c.createdAt,
                createdByUserId: c.createdByUserId,
                note: Value(c.note),
                reopenedAt: Value(c.reopenedAt),
                reopenedByUserId: Value(c.reopenedByUserId),
                reopenReason: Value(c.reopenReason)));
      }
    });
  }
}

class _DurableSnapshot extends SnapshotHolder {
  _DurableSnapshot(this.memory, this.persist);
  final SnapshotHolder memory;
  final Future<void> Function() persist;
  @override
  Future<void> capture() async => memory.capture();
  @override
  Future<void> rollback() async {
    await memory.rollback();
    await persist();
  }
}
