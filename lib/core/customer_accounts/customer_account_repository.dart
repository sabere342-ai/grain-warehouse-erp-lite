import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';

abstract class CustomerAccountRepository {
  Future<List<CustomerAccountEntry>> listEntries();
  Future<List<CustomerCollectionRecord>> listCollections();
  Future<int> balanceForCustomer(String customerId);
  Future<Map<String, int>> balancesByCustomerId();
  Future<CustomerStatement> statementForCustomer(String customerId);
  Future<CustomerAccountEntry> createCreditSaleEntry({
    required SaleRecord sale,
    required String customerId,
  });
  Future<CustomerCollectionRecord> createCollection(
    CustomerCollectionDraft draft,
  );

  Future<CustomerAccountEntry> createOpeningBalanceEntry({
    required String customerId,
    required int amountQirsh,
    required String createdByUserId,
  });

  Future<bool> hasOpeningBalanceEntry(String customerId);
}

class LocalCustomerAccountRepository implements CustomerAccountRepository {
  LocalCustomerAccountRepository({
    required CustomerRepository customerRepository,
    AuditLogRepository? auditLogRepository,
  })  : _customerRepository = customerRepository,
        _auditLogRepository = auditLogRepository;

  final CustomerRepository _customerRepository;
  final AuditLogRepository? _auditLogRepository;
  final List<CustomerAccountEntry> _entries = [];
  final List<CustomerCollectionRecord> _collections = [];
  int _generatedEntryIdCounter = 0;
  int _generatedCollectionIdCounter = 0;

  @override
  Future<List<CustomerAccountEntry>> listEntries() async {
    final sorted = [..._entries]
      ..sort((a, b) {
        final createdAt = a.createdAt.compareTo(b.createdAt);
        if (createdAt != 0) return createdAt;
        return a.id.compareTo(b.id);
      });
    return List<CustomerAccountEntry>.unmodifiable(sorted);
  }

  @override
  Future<List<CustomerCollectionRecord>> listCollections() async {
    final sorted = [..._collections]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<CustomerCollectionRecord>.unmodifiable(sorted);
  }

  @override
  Future<int> balanceForCustomer(String customerId) async {
    final id = _normalizedRequiredId(customerId, 'customerId');
    return _entries
        .where((entry) => entry.customerId == id)
        .fold<int>(0, (total, entry) => total + entry.signedBalanceImpactQirsh);
  }

  @override
  Future<Map<String, int>> balancesByCustomerId() async {
    final result = <String, int>{};
    for (final entry in _entries) {
      result[entry.customerId] =
          (result[entry.customerId] ?? 0) + entry.signedBalanceImpactQirsh;
    }
    return Map<String, int>.unmodifiable(result);
  }

  @override
  Future<CustomerStatement> statementForCustomer(String customerId) async {
    final id = _normalizedRequiredId(customerId, 'customerId');
    await _requireCustomer(id, includeInactive: true);
    final customerEntries = (await listEntries())
        .where((entry) => entry.customerId == id)
        .toList(growable: false);
    var running = 0;
    final lines = <CustomerStatementLine>[];
    for (final entry in customerEntries) {
      running += entry.signedBalanceImpactQirsh;
      lines.add(CustomerStatementLine(
        entry: entry,
        runningBalanceQirsh: running,
      ));
    }
    return CustomerStatement(
      customerId: id,
      lines: List<CustomerStatementLine>.unmodifiable(lines),
      finalBalanceQirsh: running,
    );
  }

  @override
  Future<CustomerAccountEntry> createCreditSaleEntry({
    required SaleRecord sale,
    required String customerId,
  }) async {
    final customer = await _requireCustomer(customerId, includeInactive: false);
    if (sale.paymentMode != SalePaymentMode.credit) {
      throw StateError('Only credit sales create customer receivables.');
    }
    if (sale.customerId != customer.id) {
      throw StateError('Sale customer does not match ledger customer.');
    }
    if (sale.totalQirsh <= 0 || sale.isCancelled) {
      throw StateError('Invalid credit sale for customer ledger.');
    }
    if (_entries.any((entry) =>
        entry.sourceDocumentType == 'sale' && entry.sourceDocumentId == sale.id)) {
      throw StateError('Credit sale ledger entry already exists.');
    }

    final now = DateTime.now();
    final entry = CustomerAccountEntry(
      id: _generateEntryId(now),
      customerId: customer.id,
      date: sale.createdAt,
      type: CustomerAccountEntryType.creditSale,
      debitAmountQirsh: sale.totalQirsh,
      creditAmountQirsh: 0,
      sourceDocumentType: 'sale',
      sourceDocumentId: sale.id,
      descriptionAr: '\u0628\u064a\u0639 \u0622\u062c\u0644 \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}',
      createdAt: now,
      createdByUserId: sale.createdByUserId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'customer.credit_sale.posted',
      descriptionAr:
          '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0628\u064a\u0639 \u0622\u062c\u0644 \u0639\u0644\u0649 \u0627\u0644\u0639\u0645\u064a\u0644 ${customer.name}.',
      referenceId: sale.id,
    );
    return entry;
  }

  @override
  Future<CustomerCollectionRecord> createCollection(
    CustomerCollectionDraft draft,
  ) async {
    final customer = await _requireCustomer(
      draft.customerId,
      includeInactive: true,
    );
    _validateCollectionDraft(draft);
    final balance = await balanceForCustomer(customer.id);
    if (balance <= 0) {
      throw StateError('Customer has no outstanding balance.');
    }
    if (draft.amountQirsh > balance) {
      throw StateError('Collection exceeds customer balance.');
    }

    final now = DateTime.now();
    final collection = CustomerCollectionRecord(
      id: _generateCollectionId(now),
      customerId: customer.id,
      date: draft.date,
      amountQirsh: draft.amountQirsh,
      createdAt: now,
      createdByUserId: draft.createdByUserId.trim(),
      createdByUserName: _normalizedOptionalText(draft.createdByUserName),
      notes: _normalizedOptionalText(draft.notes),
    );
    _validateCollection(collection);

    final entry = CustomerAccountEntry(
      id: _generateEntryId(now),
      customerId: customer.id,
      date: collection.date,
      type: CustomerAccountEntryType.collection,
      debitAmountQirsh: 0,
      creditAmountQirsh: collection.amountQirsh,
      sourceDocumentType: 'customerCollection',
      sourceDocumentId: collection.id,
      descriptionAr: '\u062a\u062d\u0635\u064a\u0644 \u0645\u0646 \u0627\u0644\u0639\u0645\u064a\u0644 ${customer.name}',
      createdAt: now,
      createdByUserId: collection.createdByUserId,
    );
    _validateEntry(entry);

    _collections.add(collection);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'customer.collection.recorded',
      descriptionAr:
          '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u062a\u062d\u0635\u064a\u0644 \u0645\u0646 \u0627\u0644\u0639\u0645\u064a\u0644 ${customer.name}.',
      referenceId: collection.id,
    );
    return collection;
  }

  @override
  Future<CustomerAccountEntry> createOpeningBalanceEntry({
    required String customerId,
    required int amountQirsh,
    required String createdByUserId,
  }) async {
    final id = _normalizedRequiredId(customerId, 'customerId');
    final userId = _normalizedRequiredId(createdByUserId, 'createdByUserId');
    await _requireCustomer(id, includeInactive: true);

    if (await hasOpeningBalanceEntry(id)) {
      throw StateError('Opening balance already exists for this customer.');
    }
    if (amountQirsh <= 0) {
      throw ArgumentError.value(
        amountQirsh,
        'amountQirsh',
        'Opening balance amount must be positive.',
      );
    }

    final hasTransactions = _entries.any((e) => e.customerId == id);
    if (hasTransactions) {
      throw StateError(
        'Cannot add opening balance after customer has transactions.',
      );
    }

    final now = DateTime.now();
    final entry = CustomerAccountEntry(
      id: _generateEntryId(now),
      customerId: id,
      date: now,
      type: CustomerAccountEntryType.openingBalance,
      debitAmountQirsh: amountQirsh,
      creditAmountQirsh: 0,
      sourceDocumentType: 'customerOpeningBalance',
      sourceDocumentId: 'ob-$id',
      descriptionAr: '\u0631\u0635\u064a\u062f \u0627\u0641\u062a\u062a\u0627\u062d\u064a \u0644\u0644\u0639\u0645\u064a\u0644',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'customer.opening-balance.posted',
      descriptionAr: '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0631\u0635\u064a\u062f \u0627\u0641\u062a\u062a\u0627\u062d\u064a \u0644\u0644\u0639\u0645\u064a\u0644.',
      referenceId: entry.id,
    );
    return entry;
  }

  @override
  Future<bool> hasOpeningBalanceEntry(String customerId) async {
    final id = _normalizedRequiredId(customerId, 'customerId');
    return _entries.any(
      (e) =>
          e.customerId == id &&
          e.type == CustomerAccountEntryType.openingBalance,
    );
  }

  Future<void> restoreCustomerAccountsIntoEmpty({
    required List<CustomerAccountEntry> entries,
    required List<CustomerCollectionRecord> collections,
  }) async {
    if (_entries.isNotEmpty || _collections.isNotEmpty) {
      throw StateError('Customer account repository is not empty.');
    }
    _validateUniqueRestoredEntries(entries);
    _validateUniqueRestoredCollections(collections);
    _entries.addAll(entries);
    _collections.addAll(collections);
  }

  Future<void> clearForOwnerDataWipe() async {
    _entries.clear();
    _collections.clear();
    _generatedEntryIdCounter = 0;
    _generatedCollectionIdCounter = 0;
  }

  Future<Customer> _requireCustomer(
    String customerId, {
    required bool includeInactive,
  }) async {
    final id = _normalizedRequiredId(customerId, 'customerId');
    final customers = await _customerRepository.listCustomers(
      includeInactive: true,
    );
    for (final customer in customers) {
      if (customer.id == id) {
        if (!includeInactive && !customer.isActive) {
          throw StateError('Inactive customer cannot be used for credit sale.');
        }
        return customer;
      }
    }
    throw StateError('Customer was not found.');
  }

  void _validateCollectionDraft(CustomerCollectionDraft draft) {
    _normalizedRequiredId(draft.customerId, 'customerId');
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(
        draft.amountQirsh,
        'amountQirsh',
        'Collection amount must be positive.',
      );
    }
  }

  void _validateEntry(CustomerAccountEntry entry) {
    if (!entry.hasValidId ||
        entry.customerId.trim().isEmpty ||
        entry.sourceDocumentType.trim().isEmpty ||
        entry.sourceDocumentId.trim().isEmpty ||
        entry.descriptionAr.trim().isEmpty ||
        entry.createdByUserId.trim().isEmpty) {
      throw StateError('Invalid customer ledger entry.');
    }
    if (entry.debitAmountQirsh < 0 || entry.creditAmountQirsh < 0) {
      throw StateError('Customer ledger amounts cannot be negative.');
    }
    if ((entry.debitAmountQirsh == 0 && entry.creditAmountQirsh == 0) ||
        (entry.debitAmountQirsh > 0 && entry.creditAmountQirsh > 0)) {
      throw StateError('Customer ledger entry must be debit or credit only.');
    }
  }

  void _validateCollection(CustomerCollectionRecord collection) {
    if (!collection.hasValidId ||
        collection.customerId.trim().isEmpty ||
        collection.createdByUserId.trim().isEmpty ||
        collection.amountQirsh <= 0) {
      throw StateError('Invalid customer collection.');
    }
  }

  void _validateUniqueRestoredEntries(List<CustomerAccountEntry> entries) {
    final ids = <String>{};
    final documentKeys = <String>{};
    for (final entry in entries) {
      _validateEntry(entry);
      if (!ids.add(entry.id)) {
        throw StateError('Duplicate customer ledger id.');
      }
      final key = '${entry.sourceDocumentType}:${entry.sourceDocumentId}';
      if (!documentKeys.add(key)) {
        throw StateError('Duplicate customer ledger source document.');
      }
    }
  }

  void _validateUniqueRestoredCollections(
    List<CustomerCollectionRecord> collections,
  ) {
    final ids = <String>{};
    for (final collection in collections) {
      _validateCollection(collection);
      if (!ids.add(collection.id)) {
        throw StateError('Duplicate customer collection id.');
      }
    }
  }

  String _normalizedRequiredId(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
    return normalized;
  }

  String _generateEntryId(DateTime now) {
    _generatedEntryIdCounter++;
    return 'cle-${now.microsecondsSinceEpoch}-$_generatedEntryIdCounter';
  }

  String _generateCollectionId(DateTime now) {
    _generatedCollectionIdCounter++;
    return 'col-${now.microsecondsSinceEpoch}-$_generatedCollectionIdCounter';
  }

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
