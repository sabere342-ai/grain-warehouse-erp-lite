import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart'
    as domain;
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;

class DriftCustomerRepository implements CustomerDataRepository {
  DriftCustomerRepository(this._database,
      {AuditLogRepository? auditLogRepository})
      : _auditLogRepository = auditLogRepository;

  static const _sequenceKey = 'customers';
  final db.FoundationDatabase _database;
  final AuditLogRepository? _auditLogRepository;

  @override
  Future<List<domain.Customer>> listCustomers(
      {bool includeInactive = true}) async {
    final query = _database.select(_database.customers)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (!includeInactive) query.where((row) => row.isActive.equals(true));
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.Customer> createCustomer(domain.CustomerDraft draft) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      await _ensureUnique(draft.name, draft.phone);
      final sequence = await _takeSequence();
      final now = DateTime.now();
      final customer = domain.Customer(
        id: 'cus-${now.microsecondsSinceEpoch}-$sequence',
        name: draft.name.trim(),
        phone: _optional(draft.phone),
        notes: _optional(draft.notes),
        isActive: draft.isActive,
        createdAt: now,
        updatedAt: now,
      );
      await _database.into(_database.customers).insert(_companion(customer));
      await _recordAudit('customer.created', customer);
      return customer;
    });
  }

  @override
  Future<domain.Customer> updateCustomer({
    required String customerId,
    required domain.CustomerDraft draft,
  }) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      final current = await _find(customerId);
      await _ensureUnique(draft.name, draft.phone, exceptId: customerId);
      final updated = domain.Customer(
        id: current.id,
        name: draft.name.trim(),
        phone: _optional(draft.phone),
        notes: _optional(draft.notes),
        isActive: draft.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      await (_database.update(_database.customers)
            ..where((row) => row.id.equals(customerId)))
          .write(_companion(updated));
      await _recordAudit('customer.updated', updated);
      return updated;
    });
  }

  @override
  Future<domain.Customer> setCustomerActive({
    required String customerId,
    required bool isActive,
  }) async {
    return _database.transaction(() async {
      final current = await _find(customerId);
      final updated =
          current.copyWith(isActive: isActive, updatedAt: DateTime.now());
      await (_database.update(_database.customers)
            ..where((row) => row.id.equals(customerId)))
          .write(_companion(updated));
      await _recordAudit(
          isActive ? 'customer.reactivated' : 'customer.disabled', updated);
      return updated;
    });
  }

  @override
  Future<void> restoreCustomersIntoEmpty(
      List<domain.Customer> customers) async {
    await _database.transaction(() async {
      if (await _database.customers.count().getSingle() != 0) {
        throw StateError('Customers repository is not empty.');
      }
      _validateRestored(customers);
      for (final customer in customers) {
        await _database.into(_database.customers).insert(_companion(customer));
      }
      var maximum = 0;
      for (final customer in customers) {
        final value = int.tryParse(customer.id.split('-').last) ?? 0;
        if (value > maximum) maximum = value;
      }
      await _database
          .into(_database.repositorySequences)
          .insertOnConflictUpdate(db.RepositorySequencesCompanion.insert(
              repository: _sequenceKey, nextValue: maximum + 1));
    });
  }

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.customers).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftCustomerSnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((r) => r.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.into(_database.repositorySequences).insertOnConflictUpdate(
        db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey, nextValue: value + 1));
    return value;
  }

  Future<domain.Customer> _find(String id) async {
    final row = await (_database.select(_database.customers)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw StateError('Customer was not found.');
    return _toDomain(row);
  }

  Future<void> _ensureUnique(String name, String? phone,
      {String? exceptId}) async {
    final rows = await _database.select(_database.customers).get();
    final normalizedName = _key(name);
    final normalizedPhone = _optional(phone);
    if (rows
        .any((r) => r.id != exceptId && r.normalizedName == normalizedName)) {
      throw StateError('Duplicate customer name.');
    }
    if (normalizedPhone != null &&
        rows.any((r) =>
            r.id != exceptId && r.normalizedPhone == _key(normalizedPhone))) {
      throw StateError('Duplicate customer phone.');
    }
  }

  db.CustomersCompanion _companion(domain.Customer customer) =>
      db.CustomersCompanion(
        id: Value(customer.id),
        name: Value(customer.name),
        normalizedName: Value(_key(customer.name)),
        phone: Value(customer.phone),
        normalizedPhone:
            Value(customer.phone == null ? null : _key(customer.phone!)),
        notes: Value(customer.notes),
        isActive: Value(customer.isActive),
        createdAt: Value(customer.createdAt),
        updatedAt: Value(customer.updatedAt),
      );

  domain.Customer _toDomain(db.Customer row) => domain.Customer(
        id: row.id,
        name: row.name,
        phone: row.phone,
        notes: row.notes,
        isActive: row.isActive,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  void _validateDraft(domain.CustomerDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
          draft.name, 'name', 'Customer name is required.');
    }
  }

  void _validateRestored(List<domain.Customer> customers) {
    final ids = <String>{}, names = <String>{}, phones = <String>{};
    for (final customer in customers) {
      if (!customer.hasValidId || customer.name.trim().isEmpty) {
        throw StateError('Invalid customer backup record.');
      }
      if (!ids.add(customer.id)) throw StateError('Duplicate customer id.');
      if (!names.add(_key(customer.name))) {
        throw StateError('Duplicate customer name.');
      }
      if (customer.phone != null && !phones.add(_key(customer.phone!))) {
        throw StateError('Duplicate customer phone.');
      }
    }
  }

  String _key(String value) => value.trim().toLowerCase();
  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _recordAudit(String actionType, domain.Customer customer) async {
    final descriptionAr = switch (actionType) {
      'customer.created' => 'تمت إضافة العميل ${customer.name}.',
      'customer.updated' => 'تم تعديل بيانات العميل ${customer.name}.',
      'customer.reactivated' => 'تمت إعادة تفعيل العميل ${customer.name}.',
      'customer.disabled' => 'تم إيقاف العميل ${customer.name}.',
      _ => '$actionType ${customer.name}',
    };
    await _auditLogRepository?.record(AuditLogDraft(
      actionType: actionType,
      descriptionAr: descriptionAr,
      referenceId: customer.id,
    ));
  }
}

class _DriftCustomerSnapshot extends SnapshotHolder {
  _DriftCustomerSnapshot(this.repository);
  final DriftCustomerRepository repository;
  List<domain.Customer>? customers;

  @override
  Future<void> capture() async {
    customers = await repository.listCustomers();
  }

  @override
  Future<void> rollback() async {
    final state = customers;
    if (state == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreCustomersIntoEmpty(state);
  }
}
