import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart'
    as domain;
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class DriftSupplierRepository implements SupplierDataRepository {
  DriftSupplierRepository(this._database);

  static const _sequenceKey = 'suppliers';
  final db.FoundationDatabase _database;

  @override
  Future<List<domain.Supplier>> listSuppliers(
      {bool includeInactive = true}) async {
    final query = _database.select(_database.suppliers)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (!includeInactive) query.where((row) => row.isActive.equals(true));
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<domain.Supplier> createSupplier(domain.SupplierDraft draft) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      await _ensureUnique(draft.name, draft.phone);
      final sequence = await _takeSequence();
      final now = DateTime.now();
      final supplier = domain.Supplier(
        id: 'sup-${now.microsecondsSinceEpoch}-$sequence',
        name: draft.name.trim(),
        phone: _optional(draft.phone),
        address: _optional(draft.address),
        notes: _optional(draft.notes),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await _database.into(_database.suppliers).insert(_companion(supplier));
      return supplier;
    });
  }

  @override
  Future<domain.Supplier> updateSupplier({
    required String supplierId,
    required domain.SupplierDraft draft,
  }) async {
    _validateDraft(draft);
    return _database.transaction(() async {
      final current = await _find(supplierId);
      await _ensureUnique(draft.name, draft.phone, exceptId: supplierId);
      final updated = domain.Supplier(
        id: current.id,
        name: draft.name.trim(),
        phone: _optional(draft.phone),
        address: _optional(draft.address),
        notes: _optional(draft.notes),
        isActive: current.isActive,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      );
      await (_database.update(_database.suppliers)
            ..where((row) => row.id.equals(supplierId)))
          .write(_companion(updated));
      return updated;
    });
  }

  @override
  Future<domain.Supplier> setSupplierActive({
    required String supplierId,
    required bool isActive,
  }) async {
    final current = await _find(supplierId);
    final updated =
        current.copyWith(isActive: isActive, updatedAt: DateTime.now());
    await (_database.update(_database.suppliers)
          ..where((row) => row.id.equals(supplierId)))
        .write(_companion(updated));
    return updated;
  }

  @override
  Future<void> restoreSuppliersIntoEmpty(
      List<domain.Supplier> suppliers) async {
    await _database.transaction(() async {
      if (await _database.suppliers.count().getSingle() != 0) {
        throw StateError('Suppliers repository is not empty.');
      }
      _validateRestored(suppliers);
      for (final supplier in suppliers) {
        await _database.into(_database.suppliers).insert(_companion(supplier));
      }
      var maximum = 0;
      for (final supplier in suppliers) {
        final value = int.tryParse(supplier.id.split('-').last) ?? 0;
        if (value > maximum) maximum = value;
      }
      await _database.into(_database.repositorySequences).insertOnConflictUpdate(
          db.RepositorySequencesCompanion.insert(
              repository: _sequenceKey, nextValue: maximum + 1));
    });
  }

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.suppliers).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftSupplierSnapshot(this);

  Future<int> _takeSequence() async {
    final row = await (_database.select(_database.repositorySequences)
          ..where((value) => value.repository.equals(_sequenceKey)))
        .getSingleOrNull();
    final value = row?.nextValue ?? 1;
    await _database.into(_database.repositorySequences).insertOnConflictUpdate(
        db.RepositorySequencesCompanion.insert(
            repository: _sequenceKey, nextValue: value + 1));
    return value;
  }

  Future<domain.Supplier> _find(String id) async {
    final row = await (_database.select(_database.suppliers)
          ..where((value) => value.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw StateError('Supplier was not found.');
    return _toDomain(row);
  }

  Future<void> _ensureUnique(String name, String? phone,
      {String? exceptId}) async {
    final rows = await _database.select(_database.suppliers).get();
    final normalizedPhone = _optional(phone);
    if (rows.any((row) =>
        row.id != exceptId && row.normalizedName == _key(name))) {
      throw StateError('Duplicate supplier name.');
    }
    if (normalizedPhone != null &&
        rows.any((row) =>
            row.id != exceptId &&
            row.normalizedPhone == _key(normalizedPhone))) {
      throw StateError('Duplicate supplier phone.');
    }
  }

  db.SuppliersCompanion _companion(domain.Supplier supplier) =>
      db.SuppliersCompanion(
        id: Value(supplier.id),
        name: Value(supplier.name),
        normalizedName: Value(_key(supplier.name)),
        phone: Value(supplier.phone),
        normalizedPhone:
            Value(supplier.phone == null ? null : _key(supplier.phone!)),
        address: Value(supplier.address),
        notes: Value(supplier.notes),
        isActive: Value(supplier.isActive),
        createdAt: Value(supplier.createdAt),
        updatedAt: Value(supplier.updatedAt),
      );

  domain.Supplier _toDomain(db.Supplier row) => domain.Supplier(
        id: row.id,
        name: row.name,
        phone: row.phone,
        address: row.address,
        notes: row.notes,
        isActive: row.isActive,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  void _validateDraft(domain.SupplierDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
          draft.name, 'name', 'Supplier name is required.');
    }
  }

  void _validateRestored(List<domain.Supplier> suppliers) {
    final ids = <String>{}, names = <String>{}, phones = <String>{};
    for (final supplier in suppliers) {
      if (!supplier.hasValidId || supplier.name.trim().isEmpty) {
        throw StateError('Invalid supplier backup record.');
      }
      if (!ids.add(supplier.id)) throw StateError('Duplicate supplier id.');
      if (!names.add(_key(supplier.name))) {
        throw StateError('Duplicate supplier name.');
      }
      if (supplier.phone != null && !phones.add(_key(supplier.phone!))) {
        throw StateError('Duplicate supplier phone.');
      }
    }
  }

  String _key(String value) => value.trim().toLowerCase();
  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class _DriftSupplierSnapshot extends SnapshotHolder {
  _DriftSupplierSnapshot(this.repository);
  final DriftSupplierRepository repository;
  List<domain.Supplier>? suppliers;

  @override
  Future<void> capture() async {
    suppliers = await repository.listSuppliers();
  }

  @override
  Future<void> rollback() async {
    final state = suppliers;
    if (state == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restoreSuppliersIntoEmpty(state);
  }
}
