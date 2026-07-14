import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';

abstract class SupplierRepository {
  Future<List<Supplier>> listSuppliers({bool includeInactive = true});

  Future<Supplier> createSupplier(SupplierDraft draft);

  Future<Supplier> updateSupplier({
    required String supplierId,
    required SupplierDraft draft,
  });

  Future<Supplier> setSupplierActive({
    required String supplierId,
    required bool isActive,
  });
}

class LocalSupplierRepository
    implements SupplierRepository, TransactionSnapshotProvider {
  final List<Supplier> _suppliers = [];
  int _generatedIdCounter = 0;

  @override
  Future<List<Supplier>> listSuppliers({bool includeInactive = true}) async {
    final suppliers = includeInactive
        ? _suppliers
        : _suppliers.where((supplier) => supplier.isActive).toList();
    return List<Supplier>.unmodifiable(suppliers);
  }

  @override
  Future<Supplier> createSupplier(SupplierDraft draft) async {
    _validateDraft(draft);
    _ensureUniqueName(draft.name);
    _ensureUniquePhone(draft.phone);

    final now = DateTime.now();
    final supplier = Supplier(
      id: _generateSupplierId(now),
      name: draft.name.trim(),
      phone: _normalizedOptionalText(draft.phone),
      address: _normalizedOptionalText(draft.address),
      notes: _normalizedOptionalText(draft.notes),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    if (!supplier.hasValidId) {
      throw StateError('Supplier id is required.');
    }

    _suppliers.add(supplier);
    return supplier;
  }

  @override
  Future<Supplier> updateSupplier({
    required String supplierId,
    required SupplierDraft draft,
  }) async {
    _validateDraft(draft);
    final index = _indexById(supplierId);
    final current = _suppliers[index];

    _ensureUniqueName(draft.name, exceptSupplierId: supplierId);
    _ensureUniquePhone(draft.phone, exceptSupplierId: supplierId);

    final updated = Supplier(
      id: current.id,
      name: draft.name.trim(),
      phone: _normalizedOptionalText(draft.phone),
      address: _normalizedOptionalText(draft.address),
      notes: _normalizedOptionalText(draft.notes),
      isActive: current.isActive,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );

    _suppliers[index] = updated;
    return updated;
  }

  @override
  Future<Supplier> setSupplierActive({
    required String supplierId,
    required bool isActive,
  }) async {
    final index = _indexById(supplierId);
    final current = _suppliers[index];
    final updated = current.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    _suppliers[index] = updated;
    return updated;
  }

  Future<void> restoreSuppliersIntoEmpty(List<Supplier> suppliers) async {
    if (_suppliers.isNotEmpty) {
      throw StateError('Suppliers repository is not empty.');
    }
    _validateUniqueRestoredSuppliers(suppliers);
    _suppliers.addAll(suppliers);
  }

  Future<void> clearForOwnerDataWipe() async {
    _suppliers.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    return ObjectStateSnapshot<(List<Supplier>, int)>(
      captureState: () => (
        List<Supplier>.from(_suppliers),
        _generatedIdCounter,
      ),
      restoreState: (state) {
        _suppliers
          ..clear()
          ..addAll(state.$1);
        _generatedIdCounter = state.$2;
      },
    );
  }

  void _validateDraft(SupplierDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
        draft.name,
        'name',
        'Supplier name is required.',
      );
    }
  }

  void _ensureUniqueName(String name, {String? exceptSupplierId}) {
    final normalized = _normalizedKey(name);
    final duplicate = _suppliers.any(
      (supplier) =>
          supplier.id != exceptSupplierId &&
          _normalizedKey(supplier.name) == normalized,
    );
    if (duplicate) {
      throw StateError('Duplicate supplier name.');
    }
  }

  void _ensureUniquePhone(String? phone, {String? exceptSupplierId}) {
    final normalizedPhone = _normalizedOptionalText(phone);
    if (normalizedPhone == null) {
      return;
    }

    final duplicate = _suppliers.any(
      (supplier) =>
          supplier.id != exceptSupplierId &&
          supplier.phone != null &&
          _normalizedKey(supplier.phone!) == _normalizedKey(normalizedPhone),
    );
    if (duplicate) {
      throw StateError('Duplicate supplier phone.');
    }
  }

  void _validateUniqueRestoredSuppliers(List<Supplier> suppliers) {
    final ids = <String>{};
    final names = <String>{};
    final phones = <String>{};
    for (final supplier in suppliers) {
      if (!supplier.hasValidId) {
        throw StateError('Supplier id is required.');
      }
      if (!ids.add(supplier.id)) {
        throw StateError('Duplicate supplier id.');
      }
      if (!names.add(_normalizedKey(supplier.name))) {
        throw StateError('Duplicate supplier name.');
      }
      final phone = supplier.phone;
      if (phone != null && !phones.add(_normalizedKey(phone))) {
        throw StateError('Duplicate supplier phone.');
      }
    }
  }

  int _indexById(String supplierId) {
    final index =
        _suppliers.indexWhere((supplier) => supplier.id == supplierId);
    if (index == -1) {
      throw StateError('Supplier was not found.');
    }

    return index;
  }

  String _generateSupplierId(DateTime now) {
    _generatedIdCounter++;
    return 'sup-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String _normalizedKey(String value) {
    return value.trim().toLowerCase();
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
