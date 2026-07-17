import 'dart:convert';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';

/// Durable adapter that keeps the characterized domain implementation as the
/// rule engine while loading and replacing its complete state transactionally.
/// Drift is the only persisted source of truth; no process-local delegate is
/// retained between calls.
class DriftCustomerAccountRepository
    implements DurableCustomerAccountRepository {
  DriftCustomerAccountRepository(
    this._database, {
    required CustomerRepository customerRepository,
    required AuditLogRepository auditLogRepository,
    required FinancialAccountRepository financialAccountRepository,
    required NegativeBalanceApprovalService negativeBalanceApprovalService,
  })  : _customerRepository = customerRepository,
        _auditLogRepository = auditLogRepository,
        _financialAccountRepository = financialAccountRepository,
        _negativeBalanceApprovalService = negativeBalanceApprovalService;

  final FoundationDatabase _database;
  final CustomerRepository _customerRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository _financialAccountRepository;
  final NegativeBalanceApprovalService _negativeBalanceApprovalService;

  Future<LocalCustomerAccountRepository> _load() async {
    final repository = LocalCustomerAccountRepository(
      customerRepository: _customerRepository,
      auditLogRepository: _auditLogRepository,
      financialAccountRepository: _financialAccountRepository,
      negativeBalanceApprovalService: _negativeBalanceApprovalService,
    );
    await repository.restoreCustomerAccountsIntoEmpty(
      entries: await _read('customer_account_entries', _entryFromJson),
      collections: await _read('customer_collections', _collectionFromJson),
      advances: await _read('customer_advances', _advanceFromJson),
      applications: await _read(
        'customer_advance_applications',
        _applicationFromJson,
      ),
      refunds: await _read('customer_advance_refunds', _refundFromJson),
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
            'Customer account payload is not an object.');
      }
      return decode(value.cast<String, Object?>());
    }).toList(growable: false);
  }

  Future<T> _write<T>(
      Future<T> Function(LocalCustomerAccountRepository) op) async {
    final repository = await _load();
    final result = await op(repository);
    await _persist(repository);
    return result;
  }

  Future<void> _persist(LocalCustomerAccountRepository repository) async {
    final entries = await repository.listEntries();
    final collections = await repository.listCollections();
    final advances = await repository.listAdvances();
    final applications = await repository.listAdvanceApplications();
    final refunds = await repository.listAdvanceRefunds();
    await _database.inTransaction(() async {
      await _replace('customer_account_entries', entries, (v) => v.id,
          (v) => v.customerId, (v) => v.createdAt, _entryToJson);
      await _replace('customer_collections', collections, (v) => v.id,
          (v) => v.customerId, (v) => v.createdAt, _collectionToJson);
      await _replace('customer_advances', advances, (v) => v.id,
          (v) => v.customerId, (v) => v.createdAt, _advanceToJson);
      await _replaceWithAdvance(
          'customer_advance_applications',
          applications,
          (v) => v.id,
          (v) => v.customerId,
          (v) => v.appliedAt,
          (v) => v.advanceId,
          _applicationToJson);
      await _replaceWithAdvance(
          'customer_advance_refunds',
          refunds,
          (v) => v.id,
          (v) => v.customerId,
          (v) => v.refundedAt,
          (v) => v.advanceId,
          _refundToJson);
      await _saveSequence('customer_account_entries', entries.map((v) => v.id));
      await _saveSequence('customer_collections', collections.map((v) => v.id));
      await _saveSequence('customer_payment_cancellations',
          collections.map((v) => v.cancellation?.id).whereType<String>());
      await _saveSequence('customer_advances', advances.map((v) => v.id));
      await _saveSequence(
          'customer_advance_applications', applications.map((v) => v.id));
      await _saveSequence('customer_advance_refunds', refunds.map((v) => v.id));
    });
  }

  Future<void> _replace<T>(
      String table,
      List<T> values,
      String Function(T) id,
      String Function(T) customerId,
      DateTime Function(T) occurredAt,
      Map<String, Object?> Function(T) encode) async {
    await _database.customStatement('DELETE FROM $table');
    for (final value in values) {
      await _database.customStatement(
        'INSERT INTO $table (id, customer_id, occurred_at, payload_json) VALUES (?, ?, ?, ?)',
        [
          id(value),
          customerId(value),
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
      String Function(T) customerId,
      DateTime Function(T) occurredAt,
      String Function(T) advanceId,
      Map<String, Object?> Function(T) encode) async {
    await _database.customStatement('DELETE FROM $table');
    for (final value in values) {
      await _database.customStatement(
        'INSERT INTO $table (id, customer_id, occurred_at, payload_json, advance_id) VALUES (?, ?, ?, ?, ?)',
        [
          id(value),
          customerId(value),
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
  Future<List<CustomerAccountEntry>> listEntries() async =>
      (await _load()).listEntries();
  @override
  Future<List<CustomerCollectionRecord>> listCollections() async =>
      (await _load()).listCollections();
  @override
  Future<int> balanceForCustomer(String id) async =>
      (await _load()).balanceForCustomer(id);
  @override
  Future<Map<String, int>> balancesByCustomerId() async =>
      (await _load()).balancesByCustomerId();
  @override
  Future<CustomerStatement> statementForCustomer(String id) async =>
      (await _load()).statementForCustomer(id);
  @override
  Future<List<CustomerAdvance>> listAdvances() async =>
      (await _load()).listAdvances();
  @override
  Future<List<CustomerAdvanceApplication>> listAdvanceApplications() async =>
      (await _load()).listAdvanceApplications();
  @override
  Future<List<CustomerAdvanceRefund>> listAdvanceRefunds() async =>
      (await _load()).listAdvanceRefunds();
  @override
  Future<int> remainingAdvanceQirsh(String id) async =>
      (await _load()).remainingAdvanceQirsh(id);
  @override
  Future<bool> hasOpeningBalanceEntry(String id) async =>
      (await _load()).hasOpeningBalanceEntry(id);

  @override
  Future<CustomerAccountEntry> createCreditSaleEntry(
          {required SaleRecord sale, required String customerId}) =>
      _write(
          (r) => r.createCreditSaleEntry(sale: sale, customerId: customerId));
  @override
  Future<CustomerAccountEntry> createCashSaleEntry(
          {required SaleRecord sale, required String customerId}) =>
      _write((r) => r.createCashSaleEntry(sale: sale, customerId: customerId));
  @override
  Future<CustomerCollectionRecord> createCollection(
          CustomerCollectionDraft d) =>
      _write((r) => r.createCollection(d));
  @override
  Future<CustomerAdvanceApplication> applyAdvance(
          CustomerAdvanceApplicationDraft d) =>
      _write((r) => r.applyAdvance(d));
  @override
  Future<CustomerAdvanceRefund> refundAdvance(CustomerAdvanceRefundDraft d) =>
      _write((r) => r.refundAdvance(d));
  @override
  Future<CustomerAdvanceApplication> reverseAdvanceApplication(
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
  Future<CustomerAdvanceRefund> reverseAdvanceRefund(
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
  Future<CustomerCollectionCancellation> cancelCollection(
          {required AppUser user,
          required String collectionId,
          required String reason,
          required String operationRequestId}) =>
      _write((r) => r.cancelCollection(
          user: user,
          collectionId: collectionId,
          reason: reason,
          operationRequestId: operationRequestId));
  @override
  Future<CustomerAccountEntry> createOpeningBalanceEntry(
          {required String customerId,
          required int amountQirsh,
          required String createdByUserId}) =>
      _write((r) => r.createOpeningBalanceEntry(
          customerId: customerId,
          amountQirsh: amountQirsh,
          createdByUserId: createdByUserId));
  @override
  Future<CustomerAccountEntry> reverseSaleEntry(
          {required SaleRecord cancelledSale,
          required String cancelledByUserId,
          required String cancellationReason}) =>
      _write((r) => r.reverseSaleEntry(
          cancelledSale: cancelledSale,
          cancelledByUserId: cancelledByUserId,
          cancellationReason: cancellationReason));

  @override
  Future<void> restoreCustomerAccountsIntoEmpty({
    required List<CustomerAccountEntry> entries,
    required List<CustomerCollectionRecord> collections,
    List<CustomerAdvance> advances = const [],
    List<CustomerAdvanceApplication> applications = const [],
    List<CustomerAdvanceRefund> refunds = const [],
  }) async {
    final current = await _load();
    if ((await current.listEntries()).isNotEmpty ||
        (await current.listCollections()).isNotEmpty ||
        (await current.listAdvances()).isNotEmpty ||
        (await current.listAdvanceApplications()).isNotEmpty ||
        (await current.listAdvanceRefunds()).isNotEmpty) {
      throw StateError('Customer account repository is not empty.');
    }
    await current.restoreCustomerAccountsIntoEmpty(
        entries: entries,
        collections: collections,
        advances: advances,
        applications: applications,
        refunds: refunds);
    await _persist(current);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    await _database.inTransaction(() async {
      for (final table in const [
        'customer_advance_refunds',
        'customer_advance_applications',
        'customer_advances',
        'customer_collections',
        'customer_account_entries'
      ]) {
        await _database.customStatement('DELETE FROM $table');
      }
      for (final namespace in const [
        'customer_account_entries',
        'customer_collections',
        'customer_payment_cancellations',
        'customer_advances',
        'customer_advance_applications',
        'customer_advance_refunds'
      ]) {
        await _database.customStatement(
            'DELETE FROM repository_sequences WHERE repository = ?',
            [namespace]);
      }
    });
  }

  @override
  SnapshotHolder createTransactionSnapshot() =>
      _DriftCustomerAccountSnapshot(this);
}

class _DriftCustomerAccountSnapshot extends SnapshotHolder {
  _DriftCustomerAccountSnapshot(this.repository);
  final DriftCustomerAccountRepository repository;
  LocalCustomerAccountRepository? state;
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

Map<String, Object?> _entryToJson(CustomerAccountEntry v) => {
      'id': v.id,
      'customerId': v.customerId,
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
CustomerAccountEntry _entryFromJson(Map<String, Object?> v) =>
    CustomerAccountEntry(
        id: _string(v['id'], 'id'),
        customerId: _string(v['customerId'], 'customerId'),
        date: _date(v['date'], 'date'),
        type: _enum(CustomerAccountEntryType.values, v['type'], 'entry type'),
        debitAmountQirsh: _int(v['debitAmountQirsh'], 'debitAmountQirsh'),
        creditAmountQirsh: _int(v['creditAmountQirsh'], 'creditAmountQirsh'),
        sourceDocumentType:
            _string(v['sourceDocumentType'], 'sourceDocumentType'),
        sourceDocumentId: _string(v['sourceDocumentId'], 'sourceDocumentId'),
        descriptionAr: _string(v['descriptionAr'], 'descriptionAr'),
        createdAt: _date(v['createdAt'], 'createdAt'),
        createdByUserId: _string(v['createdByUserId'], 'createdByUserId'));

Map<String, Object?> _collectionToJson(CustomerCollectionRecord v) => {
      'id': v.id,
      'customerId': v.customerId,
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
      'cancellation': v.cancellation == null
          ? null
          : {
              'id': v.cancellation!.id,
              'originalCollectionId': v.cancellation!.originalCollectionId,
              'cancelledAt': v.cancellation!.cancelledAt.toIso8601String(),
              'cancelledByUserId': v.cancellation!.cancelledByUserId,
              'reason': v.cancellation!.reason,
              'customerLedgerReversalEntryId':
                  v.cancellation!.customerLedgerReversalEntryId,
              'financialAccountReversalEntryId':
                  v.cancellation!.financialAccountReversalEntryId,
            }
    };
CustomerCollectionRecord _collectionFromJson(Map<String, Object?> v) {
  final raw = v['cancellation'];
  final c = raw == null ? null : (raw as Map).cast<String, Object?>();
  return CustomerCollectionRecord(
      id: _string(v['id'], 'id'),
      customerId: _string(v['customerId'], 'customerId'),
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
      cancellation: c == null
          ? null
          : CustomerCollectionCancellation(
              id: _string(c['id'], 'cancellation id'),
              originalCollectionId:
                  _string(c['originalCollectionId'], 'originalCollectionId'),
              cancelledAt: _date(c['cancelledAt'], 'cancelledAt'),
              cancelledByUserId:
                  _string(c['cancelledByUserId'], 'cancelledByUserId'),
              reason: _string(c['reason'], 'reason'),
              customerLedgerReversalEntryId:
                  _string(c['customerLedgerReversalEntryId'], 'reversal id'),
              financialAccountReversalEntryId:
                  c['financialAccountReversalEntryId'] as String?));
}

Map<String, Object?> _advanceToJson(CustomerAdvance v) => {
      'id': v.id,
      'customerId': v.customerId,
      'sourceCollectionId': v.sourceCollectionId,
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
CustomerAdvance _advanceFromJson(Map<String, Object?> v) => CustomerAdvance(
    id: _string(v['id'], 'id'),
    customerId: _string(v['customerId'], 'customerId'),
    sourceCollectionId: _string(v['sourceCollectionId'], 'sourceCollectionId'),
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

Map<String, Object?> _applicationToJson(CustomerAdvanceApplication v) => {
      'id': v.id,
      'advanceId': v.advanceId,
      'customerId': v.customerId,
      'amountQirsh': v.amountQirsh,
      'appliedAt': v.appliedAt.toIso8601String(),
      'createdByUserId': v.createdByUserId,
      'operationRequestId': v.operationRequestId,
      'customerLedgerEntryId': v.customerLedgerEntryId,
      'reversedAt': v.reversedAt?.toIso8601String(),
      'reversedByUserId': v.reversedByUserId,
      'reversalReason': v.reversalReason,
      'reversalLedgerEntryId': v.reversalLedgerEntryId,
    };
CustomerAdvanceApplication _applicationFromJson(Map<String, Object?> v) =>
    CustomerAdvanceApplication(
        id: _string(v['id'], 'id'),
        advanceId: _string(v['advanceId'], 'advanceId'),
        customerId: _string(v['customerId'], 'customerId'),
        amountQirsh: _int(v['amountQirsh'], 'amountQirsh'),
        appliedAt: _date(v['appliedAt'], 'appliedAt'),
        createdByUserId: _string(v['createdByUserId'], 'createdByUserId'),
        operationRequestId:
            _string(v['operationRequestId'], 'operationRequestId'),
        customerLedgerEntryId:
            _string(v['customerLedgerEntryId'], 'customerLedgerEntryId'),
        reversedAt: v['reversedAt'] == null
            ? null
            : _date(v['reversedAt'], 'reversedAt'),
        reversedByUserId: v['reversedByUserId'] as String?,
        reversalReason: v['reversalReason'] as String?,
        reversalLedgerEntryId: v['reversalLedgerEntryId'] as String?);

Map<String, Object?> _refundToJson(CustomerAdvanceRefund v) => {
      'id': v.id,
      'advanceId': v.advanceId,
      'customerId': v.customerId,
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
CustomerAdvanceRefund _refundFromJson(Map<String, Object?> v) =>
    CustomerAdvanceRefund(
        id: _string(v['id'], 'id'),
        advanceId: _string(v['advanceId'], 'advanceId'),
        customerId: _string(v['customerId'], 'customerId'),
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
