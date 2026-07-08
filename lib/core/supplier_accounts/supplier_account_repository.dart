import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

abstract class SupplierAccountRepository {
  Future<List<SupplierAccountEntry>> listEntries();
  Future<List<SupplierPaymentRecord>> listPayments();
  Future<int> balanceForSupplier(String supplierId);
  Future<Map<String, int>> balancesBySupplierId();
  Future<SupplierStatement> statementForSupplier(String supplierId);
  Future<SupplierAccountEntry> createPurchaseEntry({
    required PurchaseIntake purchase,
  });
  Future<SupplierPaymentRecord> createPayment(SupplierPaymentDraft draft);
  Future<SupplierAccountEntry> reversePurchaseEntry({
    required PurchaseIntake cancelledPurchase,
    required String cancelledByUserId,
    required String cancellationReason,
  });

  Future<SupplierAccountEntry> createOpeningBalanceEntry({
    required String supplierId,
    required int amountQirsh,
    required String createdByUserId,
  });

  Future<bool> hasOpeningBalanceEntry(String supplierId);
}

class LocalSupplierAccountRepository implements SupplierAccountRepository {
  LocalSupplierAccountRepository({
    required SupplierRepository supplierRepository,
    AuditLogRepository? auditLogRepository,
  })  : _supplierRepository = supplierRepository,
        _auditLogRepository = auditLogRepository;

  final SupplierRepository _supplierRepository;
  final AuditLogRepository? _auditLogRepository;
  final List<SupplierAccountEntry> _entries = [];
  final List<SupplierPaymentRecord> _payments = [];
  int _generatedEntryIdCounter = 0;
  int _generatedPaymentIdCounter = 0;

  @override
  Future<List<SupplierAccountEntry>> listEntries() async {
    final sorted = [..._entries]
      ..sort((a, b) {
        final createdAt = a.createdAt.compareTo(b.createdAt);
        if (createdAt != 0) return createdAt;
        return a.id.compareTo(b.id);
      });
    return List<SupplierAccountEntry>.unmodifiable(sorted);
  }

  @override
  Future<List<SupplierPaymentRecord>> listPayments() async {
    final sorted = [..._payments]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<SupplierPaymentRecord>.unmodifiable(sorted);
  }

  @override
  Future<int> balanceForSupplier(String supplierId) async {
    final id = _normalizedRequiredId(supplierId, 'supplierId');
    return _entries
        .where((entry) => entry.supplierId == id)
        .fold<int>(0, (total, entry) => total + entry.signedBalanceImpactQirsh);
  }

  @override
  Future<Map<String, int>> balancesBySupplierId() async {
    final result = <String, int>{};
    for (final entry in _entries) {
      result[entry.supplierId] =
          (result[entry.supplierId] ?? 0) + entry.signedBalanceImpactQirsh;
    }
    return Map<String, int>.unmodifiable(result);
  }

  @override
  Future<SupplierStatement> statementForSupplier(String supplierId) async {
    final id = _normalizedRequiredId(supplierId, 'supplierId');
    await _requireSupplier(id, includeInactive: true);
    final supplierEntries = (await listEntries())
        .where((entry) => entry.supplierId == id)
        .toList(growable: false);
    var running = 0;
    final lines = <SupplierStatementLine>[];
    for (final entry in supplierEntries) {
      running += entry.signedBalanceImpactQirsh;
      lines.add(SupplierStatementLine(
        entry: entry,
        runningBalanceQirsh: running,
      ));
    }
    return SupplierStatement(
      supplierId: id,
      lines: List<SupplierStatementLine>.unmodifiable(lines),
      finalBalanceQirsh: running,
    );
  }

  @override
  Future<SupplierAccountEntry> createPurchaseEntry({
    required PurchaseIntake purchase,
  }) async {
    final supplier = await _requireSupplier(
      purchase.supplierId,
      includeInactive: true,
    );
    if (purchase.isCancelled) {
      throw StateError('Cancelled purchase cannot create ledger entry.');
    }
    if (purchase.totalAmountPiasters <= 0) {
      throw StateError('Invalid purchase amount for supplier ledger.');
    }
    if (_entries.any((entry) =>
        entry.sourceDocumentType == 'purchase' &&
        entry.sourceDocumentId == purchase.id)) {
      throw StateError('Purchase ledger entry already exists.');
    }

    final now = DateTime.now();
    final entry = SupplierAccountEntry(
      id: _generateEntryId(now),
      supplierId: supplier.id,
      date: purchase.createdAt,
      type: SupplierAccountEntryType.purchase,
      debitAmountQirsh: purchase.totalAmountPiasters,
      creditAmountQirsh: 0,
      sourceDocumentType: 'purchase',
      sourceDocumentId: purchase.id,
      descriptionAr:
          'مشتريات من المورد ${supplier.name}',
      createdAt: now,
      createdByUserId: purchase.createdByUserId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'supplier.purchase.posted',
      descriptionAr:
          'تم تسجيل مشتريات من المورد ${supplier.name}.',
      referenceId: purchase.id,
    );
    return entry;
  }

  @override
  Future<SupplierPaymentRecord> createPayment(
    SupplierPaymentDraft draft,
  ) async {
    final supplier = await _requireSupplier(
      draft.supplierId,
      includeInactive: true,
    );
    _validatePaymentDraft(draft);
    final balance = await balanceForSupplier(supplier.id);
    if (balance <= 0) {
      throw StateError('Supplier has no outstanding balance.');
    }
    if (draft.amountQirsh > balance) {
      throw StateError('Payment exceeds supplier balance.');
    }

    final now = DateTime.now();
    final payment = SupplierPaymentRecord(
      id: _generatePaymentId(now),
      supplierId: supplier.id,
      date: draft.date,
      amountQirsh: draft.amountQirsh,
      createdAt: now,
      createdByUserId: draft.createdByUserId.trim(),
      createdByUserName: _normalizedOptionalText(draft.createdByUserName),
      notes: _normalizedOptionalText(draft.notes),
    );
    _validatePayment(payment);

    final entry = SupplierAccountEntry(
      id: _generateEntryId(now),
      supplierId: supplier.id,
      date: payment.date,
      type: SupplierAccountEntryType.payment,
      debitAmountQirsh: 0,
      creditAmountQirsh: payment.amountQirsh,
      sourceDocumentType: 'supplierPayment',
      sourceDocumentId: payment.id,
      descriptionAr:
          'مدفوع للمورد ${supplier.name}',
      createdAt: now,
      createdByUserId: payment.createdByUserId,
    );
    _validateEntry(entry);

    _payments.add(payment);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'supplier.payment.recorded',
      descriptionAr:
          'تم تسجيل دفع للمورد ${supplier.name}.',
      referenceId: payment.id,
    );
    return payment;
  }

  @override
  Future<SupplierAccountEntry> reversePurchaseEntry({
    required PurchaseIntake cancelledPurchase,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final userId = _normalizedRequiredId(cancelledByUserId, 'cancelledByUserId');
    final reason = _normalizedOptionalText(cancellationReason);
    if (reason == null) {
      throw ArgumentError.value(
        cancellationReason,
        'cancellationReason',
        'Cancellation reason is required.',
      );
    }

    final originalEntryIndex = _entries.indexWhere(
      (entry) =>
          entry.sourceDocumentType == 'purchase' &&
          entry.sourceDocumentId == cancelledPurchase.id,
    );
    if (originalEntryIndex < 0) {
      throw StateError('No ledger entry found for this purchase.');
    }

    final originalEntry = _entries[originalEntryIndex];
    final supplier = await _requireSupplier(
      originalEntry.supplierId,
      includeInactive: true,
    );

    final balanceBeforeReversal = await balanceForSupplier(supplier.id);
    final paymentAmount = originalEntry.debitAmountQirsh - balanceBeforeReversal;
    if (paymentAmount > 0) {
      throw StateError(
        'Cannot cancel purchase: supplier has received payments against this purchase.',
      );
    }

    final now = DateTime.now();
    final reversalEntry = SupplierAccountEntry(
      id: _generateEntryId(now),
      supplierId: originalEntry.supplierId,
      date: now,
      type: SupplierAccountEntryType.purchase,
      debitAmountQirsh: 0,
      creditAmountQirsh: originalEntry.debitAmountQirsh,
      sourceDocumentType: 'purchaseCancellation',
      sourceDocumentId: cancelledPurchase.id,
      descriptionAr:
          'إلغاء مشتريات من المورد ${supplier.name}: $reason',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(reversalEntry);
    _entries.add(reversalEntry);
    await _recordAudit(
      actionType: 'supplier.purchase.reversed',
      descriptionAr:
          'تم عكس قيد مشتريات المورد ${supplier.name}.',
      referenceId: cancelledPurchase.id,
    );
    return reversalEntry;
  }

  @override
  Future<SupplierAccountEntry> createOpeningBalanceEntry({
    required String supplierId,
    required int amountQirsh,
    required String createdByUserId,
  }) async {
    final id = _normalizedRequiredId(supplierId, 'supplierId');
    final userId = _normalizedRequiredId(createdByUserId, 'createdByUserId');
    await _requireSupplier(id, includeInactive: true);

    if (await hasOpeningBalanceEntry(id)) {
      throw StateError('Opening balance already exists for this supplier.');
    }
    if (amountQirsh <= 0) {
      throw ArgumentError.value(
        amountQirsh,
        'amountQirsh',
        'Opening balance amount must be positive.',
      );
    }

    final now = DateTime.now();
    final entry = SupplierAccountEntry(
      id: _generateEntryId(now),
      supplierId: id,
      date: now,
      type: SupplierAccountEntryType.openingBalance,
      debitAmountQirsh: amountQirsh,
      creditAmountQirsh: 0,
      sourceDocumentType: 'supplierOpeningBalance',
      sourceDocumentId: 'ob-$id',
      descriptionAr: 'رصيد افتتاحي للمورد',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'supplier.opening-balance.posted',
      descriptionAr: 'تم تسجيل رصيد افتتاحي للمورد.',
      referenceId: entry.id,
    );
    return entry;
  }

  @override
  Future<bool> hasOpeningBalanceEntry(String supplierId) async {
    final id = _normalizedRequiredId(supplierId, 'supplierId');
    return _entries.any(
      (entry) =>
          entry.supplierId == id &&
          entry.type == SupplierAccountEntryType.openingBalance,
    );
  }

  Future<void> restoreSupplierAccountsIntoEmpty({
    required List<SupplierAccountEntry> entries,
    required List<SupplierPaymentRecord> payments,
  }) async {
    if (_entries.isNotEmpty || _payments.isNotEmpty) {
      throw StateError('Supplier account repository is not empty.');
    }
    _validateUniqueRestoredEntries(entries);
    _validateUniqueRestoredPayments(payments);
    _entries.addAll(entries);
    _payments.addAll(payments);
  }

  Future<void> clearForOwnerDataWipe() async {
    _entries.clear();
    _payments.clear();
    _generatedEntryIdCounter = 0;
    _generatedPaymentIdCounter = 0;
  }

  Future<Supplier> _requireSupplier(
    String supplierId, {
    required bool includeInactive,
  }) async {
    final id = _normalizedRequiredId(supplierId, 'supplierId');
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    for (final supplier in suppliers) {
      if (supplier.id == id) {
        if (!includeInactive && !supplier.isActive) {
          throw StateError('Inactive supplier cannot be used.');
        }
        return supplier;
      }
    }
    throw StateError('Supplier was not found.');
  }

  void _validatePaymentDraft(SupplierPaymentDraft draft) {
    _normalizedRequiredId(draft.supplierId, 'supplierId');
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(
        draft.amountQirsh,
        'amountQirsh',
        'Payment amount must be positive.',
      );
    }
  }

  void _validateEntry(SupplierAccountEntry entry) {
    if (!entry.hasValidId ||
        entry.supplierId.trim().isEmpty ||
        entry.sourceDocumentType.trim().isEmpty ||
        entry.sourceDocumentId.trim().isEmpty ||
        entry.descriptionAr.trim().isEmpty ||
        entry.createdByUserId.trim().isEmpty) {
      throw StateError('Invalid supplier ledger entry.');
    }
    if (entry.debitAmountQirsh < 0 || entry.creditAmountQirsh < 0) {
      throw StateError('Supplier ledger amounts cannot be negative.');
    }
    if ((entry.debitAmountQirsh == 0 && entry.creditAmountQirsh == 0) ||
        (entry.debitAmountQirsh > 0 && entry.creditAmountQirsh > 0)) {
      throw StateError('Supplier ledger entry must be debit or credit only.');
    }
  }

  void _validatePayment(SupplierPaymentRecord payment) {
    if (!payment.hasValidId ||
        payment.supplierId.trim().isEmpty ||
        payment.createdByUserId.trim().isEmpty ||
        payment.amountQirsh <= 0) {
      throw StateError('Invalid supplier payment.');
    }
  }

  void _validateUniqueRestoredEntries(List<SupplierAccountEntry> entries) {
    final ids = <String>{};
    final documentKeys = <String>{};
    for (final entry in entries) {
      _validateEntry(entry);
      if (!ids.add(entry.id)) {
        throw StateError('Duplicate supplier ledger id.');
      }
      final key = '${entry.sourceDocumentType}:${entry.sourceDocumentId}';
      if (!documentKeys.add(key)) {
        throw StateError('Duplicate supplier ledger source document.');
      }
    }
  }

  void _validateUniqueRestoredPayments(
    List<SupplierPaymentRecord> payments,
  ) {
    final ids = <String>{};
    for (final payment in payments) {
      _validatePayment(payment);
      if (!ids.add(payment.id)) {
        throw StateError('Duplicate supplier payment id.');
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
    return 'sle-${now.microsecondsSinceEpoch}-$_generatedEntryIdCounter';
  }

  String _generatePaymentId(DateTime now) {
    _generatedPaymentIdCounter++;
    return 'spy-${now.microsecondsSinceEpoch}-$_generatedPaymentIdCounter';
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
