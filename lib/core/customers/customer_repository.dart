import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class CustomerRepository {
  Future<List<Customer>> listCustomers({bool includeInactive = true});
  Future<Customer> createCustomer(CustomerDraft draft);
  Future<Customer> updateCustomer({
    required String customerId,
    required CustomerDraft draft,
  });
  Future<Customer> setCustomerActive({
    required String customerId,
    required bool isActive,
  });
}

class LocalCustomerRepository
    implements CustomerRepository, TransactionSnapshotProvider {
  LocalCustomerRepository({AuditLogRepository? auditLogRepository})
      : _auditLogRepository = auditLogRepository;

  final AuditLogRepository? _auditLogRepository;
  final List<Customer> _customers = [];
  int _generatedIdCounter = 0;

  @override
  Future<List<Customer>> listCustomers({bool includeInactive = true}) async {
    final customers = includeInactive
        ? _customers
        : _customers.where((customer) => customer.isActive).toList();
    return List<Customer>.unmodifiable(customers);
  }

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async {
    _validateDraft(draft);
    _ensureUniqueName(draft.name);
    _ensureUniquePhone(draft.phone);

    final now = DateTime.now();
    final customer = Customer(
      id: _generateCustomerId(now),
      name: draft.name.trim(),
      phone: _normalizedOptionalText(draft.phone),
      notes: _normalizedOptionalText(draft.notes),
      isActive: draft.isActive,
      createdAt: now,
      updatedAt: now,
    );
    if (!customer.hasValidId) {
      throw StateError('Customer id is required.');
    }

    _customers.add(customer);
    await _recordAudit(
      actionType: 'customer.created',
      descriptionAr: 'تمت إضافة العميل ${customer.name}.',
      referenceId: customer.id,
    );
    return customer;
  }

  @override
  Future<Customer> updateCustomer({
    required String customerId,
    required CustomerDraft draft,
  }) async {
    _validateDraft(draft);
    final index = _indexById(customerId);
    final current = _customers[index];
    _ensureUniqueName(draft.name, exceptCustomerId: customerId);
    _ensureUniquePhone(draft.phone, exceptCustomerId: customerId);

    final updated = Customer(
      id: current.id,
      name: draft.name.trim(),
      phone: _normalizedOptionalText(draft.phone),
      notes: _normalizedOptionalText(draft.notes),
      isActive: draft.isActive,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    _customers[index] = updated;
    await _recordAudit(
      actionType: 'customer.updated',
      descriptionAr: 'تم تعديل بيانات العميل ${updated.name}.',
      referenceId: updated.id,
    );
    return updated;
  }

  @override
  Future<Customer> setCustomerActive({
    required String customerId,
    required bool isActive,
  }) async {
    final index = _indexById(customerId);
    final current = _customers[index];
    final updated = current.copyWith(
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    _customers[index] = updated;
    await _recordAudit(
      actionType: isActive ? 'customer.reactivated' : 'customer.disabled',
      descriptionAr: isActive
          ? 'تمت إعادة تفعيل العميل ${updated.name}.'
          : 'تم إيقاف العميل ${updated.name}.',
      referenceId: updated.id,
    );
    return updated;
  }

  Future<void> restoreCustomersIntoEmpty(List<Customer> customers) async {
    if (_customers.isNotEmpty) {
      throw StateError('Customers repository is not empty.');
    }
    _validateUniqueRestoredCustomers(customers);
    _customers.addAll(customers);
  }

  Future<void> clearForOwnerDataWipe() async {
    _customers.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    return ObjectStateSnapshot<(List<Customer>, int)>(
      captureState: () => (
        List<Customer>.from(_customers),
        _generatedIdCounter,
      ),
      restoreState: (state) {
        _customers
          ..clear()
          ..addAll(state.$1);
        _generatedIdCounter = state.$2;
      },
    );
  }

  void _validateDraft(CustomerDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError.value(
          draft.name, 'name', 'Customer name is required.');
    }
  }

  void _ensureUniqueName(String name, {String? exceptCustomerId}) {
    final normalized = _normalizedKey(name);
    final duplicate = _customers.any(
      (customer) =>
          customer.id != exceptCustomerId &&
          _normalizedKey(customer.name) == normalized,
    );
    if (duplicate) {
      throw StateError('Duplicate customer name.');
    }
  }

  void _ensureUniquePhone(String? phone, {String? exceptCustomerId}) {
    final normalizedPhone = _normalizedOptionalText(phone);
    if (normalizedPhone == null) {
      return;
    }
    final duplicate = _customers.any(
      (customer) =>
          customer.id != exceptCustomerId &&
          customer.phone != null &&
          _normalizedKey(customer.phone!) == _normalizedKey(normalizedPhone),
    );
    if (duplicate) {
      throw StateError('Duplicate customer phone.');
    }
  }

  void _validateUniqueRestoredCustomers(List<Customer> customers) {
    final ids = <String>{};
    final names = <String>{};
    final phones = <String>{};
    for (final customer in customers) {
      if (!customer.hasValidId || customer.name.trim().isEmpty) {
        throw StateError('Invalid customer backup record.');
      }
      if (!ids.add(customer.id)) {
        throw StateError('Duplicate customer id.');
      }
      if (!names.add(_normalizedKey(customer.name))) {
        throw StateError('Duplicate customer name.');
      }
      final phone = customer.phone;
      if (phone != null && !phones.add(_normalizedKey(phone))) {
        throw StateError('Duplicate customer phone.');
      }
    }
  }

  int _indexById(String customerId) {
    final index =
        _customers.indexWhere((customer) => customer.id == customerId);
    if (index == -1) {
      throw StateError('Customer was not found.');
    }
    return index;
  }

  String _generateCustomerId(DateTime now) {
    _generatedIdCounter++;
    return 'cus-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  String _normalizedKey(String value) => value.trim().toLowerCase();

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _recordAudit({
    required String actionType,
    required String descriptionAr,
    String? referenceId,
  }) async {
    await _auditLogRepository?.record(
      AuditLogDraft(
        actionType: actionType,
        descriptionAr: descriptionAr,
        referenceId: referenceId,
      ),
    );
  }
}
