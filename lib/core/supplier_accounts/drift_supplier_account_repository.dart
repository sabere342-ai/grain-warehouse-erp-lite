import 'dart:convert';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';

/// Durable adapter that keeps the characterized domain implementation as the
/// rule engine while loading and replacing its complete state transactionally.
/// Drift is the only persisted source of truth; no process-local delegate is
/// retained between calls.
class DriftSupplierAccountRepository
    implements DurableSupplierAccountRepository {
  DriftSupplierAccountRepository(
    this._database, {
    required SupplierRepository supplierRepository,
    required AuditLogRepository auditLogRepository,
    required FinancialAccountRepository financialAccountRepository,
    required NegativeBalanceApprovalService negativeBalanceApprovalService,
  })  : _supplierRepository = supplierRepository,
        _auditLogRepository = auditLogRepository,
        _financialAccountRepository = financialAccountRepository,
        _negativeBalanceApprovalService = negativeBalanceApprovalService;

  final FoundationDatabase _database;
  final SupplierRepository _supplierRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository _financialAccountRepository;
  final NegativeBalanceApprovalService _negativeBalanceApprovalService;

  Future<LocalSupplierAccountRepository> _load() async {
    final repository = LocalSupplierAccountRepository(
      supplierRepository: _supplierRepository,
      auditLogRepository: _auditLogRepository,
      financialAccountRepository: _financialAccountRepository,
      negativeBalanceApprovalService: _negativeBalanceApprovalService,
    );
    await repository.restoreSupplierAccountsIntoEmpty(
      entries: await _read('supplier_account_entries', _entryFromJson),
      payments: await _read('supplier_payments', _paymentFromJson),
      advances: await _read('supplier_advances', _advanceFromJson),
      applications: await _read(
        'supplier_advance_applications',
        _applicationFromJson,
      ),
      refunds: await _read('supplier_advance_refunds', _refundFromJson),
    );
    return repository;
  }

  Future<List<T>> _read<T>(
    String table,
    T Function(Map<String, Object?>) decode,
  ) async {
    final rows = await _database
        .customSelect(
          'SELECT payload_json FROM $table ORDER BY occurred_at, id',
        )
        .get();
    return rows.map((row) {
      final value = jsonDecode(row.read<String>('payload_json'));
      if (value is! Map<String, dynamic>) {
        throw const FormatException(
            'Supplier account payload is not an object.');
      }
      return decode(value.cast<String, Object?>());
    }).toList(growable: false);
  }

  Future<T> _write<T>(
      Future<T> Function(LocalSupplierAccountRepository) op) async {
    final repository = await _load();
    final result = await op(repository);
    await _persist(repository);
    return result;
  }

  Future<void> _persist(LocalSupplierAccountRepository repository) async {
    final entries = await repository.listEntries();
    final payments = await repository.listPayments();
    final advances = await repository.listAdvances();
    final applications = await repository.listAdvanceApplications();
    final refunds = await repository.listAdvanceRefunds();
    await _database.inTransaction(() async {
      await _replace('supplier_account_entries', entries, (v) => v.id,
          (v) => v.supplierId, (v) => v.createdAt, _entryToJson);
      await _replace('supplier_payments', payments, (v) => v.id,
          (v) => v.supplierId, (v) => v.createdAt, _paymentToJson);
      await _replace('supplier_advances', advances, (v) => v.id,
          (v) => v.supplierId, (v) => v.createdAt, _advanceToJson);
      await _replaceWithAdvance(
          'supplier_advance_applications',
          applications,
          (v) => v.id,
          (v) => v.supplierId,
          (v) => v.appliedAt,
          (v) => v.advanceId,
          _applicationToJson);
      await _replaceWithAdvance(
          'supplier_advance_refunds',
          refunds,
          (v) => v.id,
          (v) => v.supplierId,
          (v) => v.refundedAt,
          (v) => v.advanceId,
          _refundToJson);
      await _saveSequence('supplier_account_entries', entries.map((v) => v.id));
      await _saveSequence('supplier_payments', payments.map((v) => v.id));
      await _saveSequence('supplier_payment_cancellations',
          payments.map((v) => v.cancellation?.id).whereType<String>());
      await _saveSequence('supplier_advances', advances.map((v) => v.id));
      await _saveSequence(
          'supplier_advance_applications', applications.map((v) => v.id));
      await _saveSequence('supplier_advance_refunds', refunds.map((v) => v.id));
    });
  }

  Future<void> _replace<T>(
      String table,
      List<T> values,
      String Function(T) id,
      String Function(T) supplierId,
      DateTime Function(T) occurredAt,
      Map<String, Object?> Function(T) encode) async {
    await _database.customStatement('DELETE FROM $table');
    for (final value in values) {
      await _database.customStatement(
        'INSERT INTO $table (id, supplier_id, occurred_at, payload_json) VALUES (?, ?, ?, ?)',
        [
          id(value),
          supplierId(value),
          occurredAt(value).toIso8601String(),
          jsonEncode(encode(value))
        ],
      );
    }
  }

  Future<void> _replaceWithAdvance<T>(
      String table,
      List<T> values,
      String Function(T) id,
      String Function(T) supplierId,
      DateTime Function(T) occurredAt,
      String Function(T) advanceId,
      Map<String, Object?> Function(T) encode) async {
    await _database.customStatement('DELETE FROM $table');
    for (final value in values) {
      await _database.customStatement(
        'INSERT INTO $table (id, supplier_id, occurred_at, payload_json, advance_id) VALUES (?, ?, ?, ?, ?)',
        [
          id(value),
          supplierId(value),
          occurredAt(value).toIso8601String(),
          jsonEncode(encode(value)),
          advanceId(value)
        ],
      );
    }
  }

  Future<void> _saveSequence(String namespace, Iterable<String> ids) async {
    var maximum = 0;
    for (final id in ids) {
      final value = int.tryParse(id.split('-').last);
      if (value != null && value > maximum) maximum = value;
    }
    await _database.customStatement(
      'INSERT INTO repository_sequences (repository, next_value) VALUES (?, ?) '
      'ON CONFLICT(repository) DO UPDATE SET next_value = excluded.next_value',
      [namespace, maximum + 1],
    );
  }

  @override
  Future<List<SupplierAccountEntry>> listEntries() async =>
      (await _load()).listEntries();
  @override
  Future<List<SupplierPaymentRecord>> listPayments() async =>
      (await _load()).listPayments();
  @override
  Future<int> balanceForSupplier(String id) async =>
      (await _load()).balanceForSupplier(id);
  @override
  Future<Map<String, int>> balancesBySupplierId() async =>
      (await _load()).balancesBySupplierId();
  @override
  Future<SupplierStatement> statementForSupplier(String id) async =>
      (await _load()).statementForSupplier(id);
  @override
  Future<List<SupplierAdvance>> listAdvances() async =>
      (await _load()).listAdvances();
  @override
  Future<List<SupplierAdvanceApplication>> listAdvanceApplications() async =>
      (await _load()).listAdvanceApplications();
  @override
  Future<List<SupplierAdvanceRefund>> listAdvanceRefunds() async =>
      (await _load()).listAdvanceRefunds();
  @override
  Future<int> remainingAdvanceQirsh(String id) async =>
      (await _load()).remainingAdvanceQirsh(id);
  @override
  Future<bool> hasOpeningBalanceEntry(String id) async =>
      (await _load()).hasOpeningBalanceEntry(id);

  @override
  Future<SupplierAccountEntry> createPurchaseEntry({
    required PurchaseIntake purchase,
  }) =>
      _write((r) => r.createPurchaseEntry(purchase: purchase));
  @override
  Future<SupplierPaymentRecord> createPayment(SupplierPaymentDraft d) async {
    final requestId = d.operationRequestId?.trim();
    if (requestId != null && requestId.isNotEmpty) {
      final fingerprint = _paymentDraftFingerprint(d);
      for (final payment in await listPayments()) {
        if (payment.operationRequestId == requestId) {
          if (payment.operationRequestFingerprint != fingerprint) {
            throw StateError('Request id payload mismatch.');
          }
          return payment;
        }
      }
    }
    return _write((r) => r.createPayment(d));
  }

  @override
  Future<SupplierAdvanceApplication> applyAdvance(
          SupplierAdvanceApplicationDraft d) =>
      _write((r) => r.applyAdvance(d));
  @override
  Future<SupplierAdvanceRefund> refundAdvance(SupplierAdvanceRefundDraft d) =>
      _write((r) => r.refundAdvance(d));
  @override
  Future<SupplierAdvanceApplication> reverseAdvanceApplication(
          {required AppUser user,
          required String applicationId,
          required String reason,
          required String operationRequestId}) =>
      _write((r) => r.reverseAdvanceApplication(
          user: user,
          applicationId: applicationId,
          reason: reason,
          operationRequestId: operationRequestId));
  @override
  Future<SupplierAdvanceRefund> reverseAdvanceRefund(
          {required AppUser user,
          required String refundId,
          required String reason,
          required String operationRequestId,
          String? overpaymentApprovalId}) =>
      _write((r) => r.reverseAdvanceRefund(
          user: user,
          refundId: refundId,
          reason: reason,
          operationRequestId: operationRequestId,
          overpaymentApprovalId: overpaymentApprovalId));
  @override
  Future<SupplierPaymentCancellation> cancelPayment(
      {required AppUser user,
      required String paymentId,
      required String reason,
      required String operationRequestId}) async {
    for (final payment in await listPayments()) {
      final cancellation = payment.cancellation;
      if (cancellation?.operationRequestId == operationRequestId.trim()) {
        if (cancellation!.originalPaymentId != paymentId.trim() ||
            cancellation.reason != reason.trim() ||
            cancellation.cancelledByUserId != user.id) {
          throw StateError('Request id payload mismatch.');
        }
        return cancellation;
      }
    }
    return _write((r) => r.cancelPayment(
        user: user,
        paymentId: paymentId,
        reason: reason,
        operationRequestId: operationRequestId));
  }

  @override
  Future<SupplierAccountEntry> createOpeningBalanceEntry(
          {required String supplierId,
          required int amountQirsh,
          required String createdByUserId}) =>
      _write((r) => r.createOpeningBalanceEntry(
          supplierId: supplierId,
          amountQirsh: amountQirsh,
          createdByUserId: createdByUserId));
  @override
  Future<SupplierAccountEntry> reversePurchaseEntry(
          {required PurchaseIntake cancelledPurchase,
          required String cancelledByUserId,
          required String cancellationReason}) =>
      _write((r) => r.reversePurchaseEntry(
          cancelledPurchase: cancelledPurchase,
          cancelledByUserId: cancelledByUserId,
          cancellationReason: cancellationReason));

  @override
  Future<void> restoreSupplierAccountsIntoEmpty({
    required List<SupplierAccountEntry> entries,
    required List<SupplierPaymentRecord> payments,
    List<SupplierAdvance> advances = const [],
    List<SupplierAdvanceApplication> applications = const [],
    List<SupplierAdvanceRefund> refunds = const [],
  }) async {
    final current = await _load();
    if ((await current.listEntries()).isNotEmpty ||
        (await current.listPayments()).isNotEmpty ||
        (await current.listAdvances()).isNotEmpty ||
        (await current.listAdvanceApplications()).isNotEmpty ||
        (await current.listAdvanceRefunds()).isNotEmpty) {
      throw StateError('Supplier account repository is not empty.');
    }
    await current.restoreSupplierAccountsIntoEmpty(
        entries: entries,
        payments: payments,
        advances: advances,
        applications: applications,
        refunds: refunds);
    await _persist(current);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    await _database.inTransaction(() async {
      for (final table in const [
        'supplier_advance_refunds',
        'supplier_advance_applications',
        'supplier_advances',
        'supplier_payments',
        'supplier_account_entries'
      ]) {
        await _database.customStatement('DELETE FROM $table');
      }
      for (final namespace in const [
        'supplier_account_entries',
        'supplier_payments',
        'supplier_payment_cancellations',
        'supplier_advances',
        'supplier_advance_applications',
        'supplier_advance_refunds'
      ]) {
        await _database.customStatement(
            'DELETE FROM repository_sequences WHERE repository = ?',
            [namespace]);
      }
    });
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _DriftSupplierAccountSnapshot(this);
}

class _DriftSupplierAccountSnapshot extends SnapshotHolder {
  _DriftSupplierAccountSnapshot(this.repository);
  final DriftSupplierAccountRepository repository;
  LocalSupplierAccountRepository? state;
  @override
  Future<void> capture() async => state = await repository._load();
  @override
  Future<void> rollback() async {
    final value = state;
    if (value != null) await repository._persist(value);
  }
}

DateTime _date(Object? value, String field) {
  if (value is! String) throw FormatException('Invalid $field.');
  final result = DateTime.tryParse(value);
  if (result == null) throw FormatException('Invalid $field.');
  return result;
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('Invalid $field.');
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('Invalid $field.');
  return value;
}

T _enum<T extends Enum>(List<T> values, Object? value, String field) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  throw FormatException('Unknown $field value: $value');
}

String _paymentDraftFingerprint(SupplierPaymentDraft draft) => [
      draft.supplierId.trim(),
      draft.date.toUtc().toIso8601String(),
      draft.amountQirsh,
      draft.createdByUserId.trim(),
      draft.financialAccountId?.trim() ?? '',
      draft.paymentMethod?.name ?? '',
      draft.negativeBalanceApprovalId?.trim() ?? '',
    ].join('|');

Map<String, Object?> _entryToJson(SupplierAccountEntry v) => {
      'id': v.id,
      'supplierId': v.supplierId,
      'date': v.date.toIso8601String(),
      'type': v.type.name,
      'debitAmountQirsh': v.debitAmountQirsh,
      'creditAmountQirsh': v.creditAmountQirsh,
      'sourceDocumentType': v.sourceDocumentType,
      'sourceDocumentId': v.sourceDocumentId,
      'descriptionAr': v.descriptionAr,
      'createdAt': v.createdAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
    };
SupplierAccountEntry _entryFromJson(Map<String, Object?> v) =>
    SupplierAccountEntry(
        id: _string(v['id'], 'id'),
        supplierId: _string(v['supplierId'], 'supplierId'),
        date: _date(v['date'], 'date'),
        type: _enum(SupplierAccountEntryType.values, v['type'], 'entry type'),
        debitAmountQirsh: _int(v['debitAmountQirsh'], 'debitAmountQirsh'),
        creditAmountQirsh: _int(v['creditAmountQirsh'], 'creditAmountQirsh'),
        sourceDocumentType:
            _string(v['sourceDocumentType'], 'sourceDocumentType'),
        sourceDocumentId: _string(v['sourceDocumentId'], 'sourceDocumentId'),
        descriptionAr: _string(v['descriptionAr'], 'descriptionAr'),
        createdAt: _date(v['createdAt'], 'createdAt'),
        createdByUserId: _string(v['createdByUserId'], 'createdByUserId'));

Map<String, Object?> _paymentToJson(SupplierPaymentRecord v) => {
      'id': v.id,
      'supplierId': v.supplierId,
      'date': v.date.toIso8601String(),
      'amountQirsh': v.amountQirsh,
      'createdAt': v.createdAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
      'createdByUserName': v.createdByUserName,
      'notes': v.notes,
      'financialAccountId': v.financialAccountId,
      'paymentMethod': v.paymentMethod?.name,
      'settledAmountQirsh': v.settledAmountQirsh,
      'advanceAmountQirsh': v.advanceAmountQirsh,
      'operationRequestId': v.operationRequestId,
      'operationRequestFingerprint': v.operationRequestFingerprint,
      'cancellation': v.cancellation == null
          ? null
          : {
              'id': v.cancellation!.id,
              'originalPaymentId': v.cancellation!.originalPaymentId,
              'cancelledAt': v.cancellation!.cancelledAt.toIso8601String(),
              'cancelledByUserId': v.cancellation!.cancelledByUserId,
              'reason': v.cancellation!.reason,
              'supplierLedgerReversalEntryId':
                  v.cancellation!.supplierLedgerReversalEntryId,
              'operationRequestId': v.cancellation!.operationRequestId,
              'financialAccountReversalEntryId':
                  v.cancellation!.financialAccountReversalEntryId,
            }
    };
SupplierPaymentRecord _paymentFromJson(Map<String, Object?> v) {
  final raw = v['cancellation'];
  final c = raw == null ? null : (raw as Map).cast<String, Object?>();
  return SupplierPaymentRecord(
      id: _string(v['id'], 'id'),
      supplierId: _string(v['supplierId'], 'supplierId'),
      date: _date(v['date'], 'date'),
      amountQirsh: _int(v['amountQirsh'], 'amountQirsh'),
      createdAt: _date(v['createdAt'], 'createdAt'),
      createdByUserId: _string(v['createdByUserId'], 'createdByUserId'),
      createdByUserName: v['createdByUserName'] as String?,
      notes: v['notes'] as String?,
      financialAccountId: v['financialAccountId'] as String?,
      paymentMethod: v['paymentMethod'] == null
          ? null
          : _enum(PaymentMethod.values, v['paymentMethod'], 'payment method'),
      settledAmountQirsh: v['settledAmountQirsh'] as int?,
      advanceAmountQirsh: _int(v['advanceAmountQirsh'], 'advanceAmountQirsh'),
      operationRequestId: v['operationRequestId'] as String?,
      operationRequestFingerprint: v['operationRequestFingerprint'] as String?,
      cancellation: c == null
          ? null
          : SupplierPaymentCancellation(
              id: _string(c['id'], 'cancellation id'),
              originalPaymentId:
                  _string(c['originalPaymentId'], 'originalPaymentId'),
              cancelledAt: _date(c['cancelledAt'], 'cancelledAt'),
              cancelledByUserId:
                  _string(c['cancelledByUserId'], 'cancelledByUserId'),
              reason: _string(c['reason'], 'reason'),
              supplierLedgerReversalEntryId:
                  _string(c['supplierLedgerReversalEntryId'], 'reversal id'),
              operationRequestId: c['operationRequestId'] as String?,
              financialAccountReversalEntryId:
                  c['financialAccountReversalEntryId'] as String?));
}

Map<String, Object?> _advanceToJson(SupplierAdvance v) => {
      'id': v.id,
      'supplierId': v.supplierId,
      'sourcePaymentId': v.sourcePaymentId,
      'financialAccountId': v.financialAccountId,
      'amountQirsh': v.amountQirsh,
      'createdAt': v.createdAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
      'ownerApprovalId': v.ownerApprovalId,
      'operationRequestId': v.operationRequestId,
      'paymentMethod': v.paymentMethod?.name,
      'reversedAt': v.reversedAt?.toIso8601String(),
      'reversedByUserId': v.reversedByUserId,
    };
SupplierAdvance _advanceFromJson(Map<String, Object?> v) => SupplierAdvance(
    id: _string(v['id'], 'id'),
    supplierId: _string(v['supplierId'], 'supplierId'),
    sourcePaymentId: _string(v['sourcePaymentId'], 'sourcePaymentId'),
    financialAccountId: _string(v['financialAccountId'], 'financialAccountId'),
    amountQirsh: _int(v['amountQirsh'], 'amountQirsh'),
    createdAt: _date(v['createdAt'], 'createdAt'),
    createdByUserId: _string(v['createdByUserId'], 'createdByUserId'),
    ownerApprovalId: _string(v['ownerApprovalId'], 'ownerApprovalId'),
    operationRequestId: _string(v['operationRequestId'], 'operationRequestId'),
    paymentMethod: v['paymentMethod'] == null
        ? null
        : _enum(PaymentMethod.values, v['paymentMethod'], 'payment method'),
    reversedAt:
        v['reversedAt'] == null ? null : _date(v['reversedAt'], 'reversedAt'),
    reversedByUserId: v['reversedByUserId'] as String?);

Map<String, Object?> _applicationToJson(SupplierAdvanceApplication v) => {
      'id': v.id,
      'advanceId': v.advanceId,
      'supplierId': v.supplierId,
      'amountQirsh': v.amountQirsh,
      'appliedAt': v.appliedAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
      'operationRequestId': v.operationRequestId,
      'supplierLedgerEntryId': v.supplierLedgerEntryId,
      'reversedAt': v.reversedAt?.toIso8601String(),
      'reversedByUserId': v.reversedByUserId,
      'reversalReason': v.reversalReason,
      'reversalLedgerEntryId': v.reversalLedgerEntryId,
    };
SupplierAdvanceApplication _applicationFromJson(Map<String, Object?> v) =>
    SupplierAdvanceApplication(
        id: _string(v['id'], 'id'),
        advanceId: _string(v['advanceId'], 'advanceId'),
        supplierId: _string(v['supplierId'], 'supplierId'),
        amountQirsh: _int(v['amountQirsh'], 'amountQirsh'),
        appliedAt: _date(v['appliedAt'], 'appliedAt'),
        createdByUserId: _string(v['createdByUserId'], 'createdByUserId'),
        operationRequestId:
            _string(v['operationRequestId'], 'operationRequestId'),
        supplierLedgerEntryId:
            _string(v['supplierLedgerEntryId'], 'supplierLedgerEntryId'),
        reversedAt: v['reversedAt'] == null
            ? null
            : _date(v['reversedAt'], 'reversedAt'),
        reversedByUserId: v['reversedByUserId'] as String?,
        reversalReason: v['reversalReason'] as String?,
        reversalLedgerEntryId: v['reversalLedgerEntryId'] as String?);

Map<String, Object?> _refundToJson(SupplierAdvanceRefund v) => {
      'id': v.id,
      'advanceId': v.advanceId,
      'supplierId': v.supplierId,
      'financialAccountId': v.financialAccountId,
      'amountQirsh': v.amountQirsh,
      'refundedAt': v.refundedAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
      'operationRequestId': v.operationRequestId,
      'financialEntryId': v.financialEntryId,
      'reversedAt': v.reversedAt?.toIso8601String(),
      'reversedByUserId': v.reversedByUserId,
      'reversalReason': v.reversalReason,
      'reversalFinancialEntryId': v.reversalFinancialEntryId,
    };
SupplierAdvanceRefund _refundFromJson(Map<String, Object?> v) =>
    SupplierAdvanceRefund(
        id: _string(v['id'], 'id'),
        advanceId: _string(v['advanceId'], 'advanceId'),
        supplierId: _string(v['supplierId'], 'supplierId'),
        financialAccountId:
            _string(v['financialAccountId'], 'financialAccountId'),
        amountQirsh: _int(v['amountQirsh'], 'amountQirsh'),
        refundedAt: _date(v['refundedAt'], 'refundedAt'),
        createdByUserId: _string(v['createdByUserId'], 'createdByUserId'),
        operationRequestId:
            _string(v['operationRequestId'], 'operationRequestId'),
        financialEntryId: _string(v['financialEntryId'], 'financialEntryId'),
        reversedAt: v['reversedAt'] == null
            ? null
            : _date(v['reversedAt'], 'reversedAt'),
        reversedByUserId: v['reversedByUserId'] as String?,
        reversalReason: v['reversalReason'] as String?,
        reversalFinancialEntryId: v['reversalFinancialEntryId'] as String?);
