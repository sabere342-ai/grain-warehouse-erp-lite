import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

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
  Future<SupplierPaymentCancellation> cancelPayment({
    required AppUser user,
    required String paymentId,
    required String reason,
    required String operationRequestId,
  });
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

class LocalSupplierAccountRepository
    implements SupplierAccountRepository, TransactionSnapshotProvider {
  LocalSupplierAccountRepository({
    required SupplierRepository supplierRepository,
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
  })  : _supplierRepository = supplierRepository,
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository;

  final SupplierRepository _supplierRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final List<SupplierAccountEntry> _entries = [];
  final List<SupplierPaymentRecord> _payments = [];
  final Map<String, String> _paymentRequestFingerprints = {};
  final Map<String, String> _cancellationRequestIds = {};
  int _generatedEntryIdCounter = 0;
  int _generatedPaymentIdCounter = 0;
  int _generatedCancellationIdCounter = 0;

  @override
  Future<List<SupplierAccountEntry>> listEntries() async {
    final sorted = [..._entries]..sort((a, b) {
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
      descriptionAr: 'مشتريات من المورد ${supplier.name}',
      createdAt: now,
      createdByUserId: purchase.createdByUserId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'supplier.purchase.posted',
      descriptionAr: 'تم تسجيل مشتريات من المورد ${supplier.name}.',
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
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
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
      descriptionAr: 'مدفوع للمورد ${supplier.name}',
      createdAt: now,
      createdByUserId: payment.createdByUserId,
    );
    _validateEntry(entry);

    final requestId = _normalizedOptionalText(draft.operationRequestId);
    final requestFingerprint = _paymentFingerprint(draft);

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    if (_financialAccountRepository is TransactionSnapshotProvider) {
      snapshots.add((_financialAccountRepository as TransactionSnapshotProvider)
          .createTransactionSnapshot());
    }
    return RepositoryTransaction.execute(snapshots, () async {
      if (requestId != null &&
          _paymentRequestFingerprints.containsKey(requestId)) {
        throw StateError('Supplier payment request was already processed.');
      }
      final lockedBalance = await balanceForSupplier(supplier.id);
      if (lockedBalance <= 0 || draft.amountQirsh > lockedBalance) {
        throw StateError('Payment exceeds supplier balance.');
      }
      _payments.add(payment);
      _entries.add(entry);
      await _recordAudit(
        actionType: 'supplier.payment.recorded',
        descriptionAr: 'تم تسجيل دفع للمورد ${supplier.name}.',
        referenceId: payment.id,
      );

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          payment.financialAccountId != null &&
          payment.financialAccountId!.isNotEmpty) {
        await faRepo.createEntry(
          accountId: payment.financialAccountId!,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: payment.amountQirsh,
          sourceType: FinancialAccountEntrySource.supplierSettlement,
          sourceDocumentId: payment.id,
          effectiveDate: payment.date,
          createdByUserId: payment.createdByUserId,
          reference: 'تسوية مع المورد ${supplier.name}',
          note: 'دفع للمورد ${payment.amountQirsh} قيرش',
          paymentMethod: payment.paymentMethod,
          approvedByUserId: draft.approvedByUserId,
          negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
          approvalSourceDocumentId: draft.operationRequestId,
        );
      }

      if (requestId != null) {
        _paymentRequestFingerprints[requestId] = requestFingerprint;
      }

      return payment;
    });
  }

  @override
  Future<SupplierPaymentCancellation> cancelPayment({
    required AppUser user,
    required String paymentId,
    required String reason,
    required String operationRequestId,
  }) async {
    _requireOwner(user);
    final id = _normalizedRequiredId(paymentId, 'paymentId');
    final cleanReason = _normalizedRequiredText(reason, 'reason');
    final requestId = _normalizedRequiredText(
      operationRequestId,
      'operationRequestId',
    );
    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    final financialRepository = _financialAccountRepository;
    if (financialRepository != null) {
      if (financialRepository is! TransactionSnapshotProvider) {
        throw StateError(
            'Financial account repository does not support atomic transactions.');
      }
      snapshots.add(
        (financialRepository as TransactionSnapshotProvider)
            .createTransactionSnapshot(),
      );
    }
    return RepositoryTransaction.execute(snapshots, () async {
      if (_cancellationRequestIds.containsKey(requestId)) {
        throw StateError(
            'Supplier payment cancellation request was already processed.');
      }
      final index = _payments.indexWhere((payment) => payment.id == id);
      if (index < 0) throw StateError('Supplier payment was not found.');
      final payment = _payments[index];
      if (payment.isCancelled) {
        throw StateError('Supplier payment was already cancelled.');
      }
      final supplier = await _requireSupplier(
        payment.supplierId,
        includeInactive: true,
      );
      final now = DateTime.now();
      final cancellationId = _generateCancellationId(now);
      final ledgerReversal = SupplierAccountEntry(
        id: _generateEntryId(now),
        supplierId: payment.supplierId,
        date: now,
        type: SupplierAccountEntryType.paymentCancellation,
        debitAmountQirsh: payment.amountQirsh,
        creditAmountQirsh: 0,
        sourceDocumentType: 'supplierPaymentCancellation',
        sourceDocumentId: cancellationId,
        descriptionAr: 'عكس دفعة المورد ${supplier.name}: $cleanReason',
        createdAt: now,
        createdByUserId: user.id,
      );
      _validateEntry(ledgerReversal);
      _entries.add(ledgerReversal);

      String? financialReversalEntryId;
      if (payment.financialAccountId?.trim().isNotEmpty == true) {
        final statement = await financialRepository!.statementForAccount(
          payment.financialAccountId!,
        );
        FinancialAccountEntry? originalFinancialEntry;
        for (final line in statement.lines) {
          if (line.entry.sourceType ==
                  FinancialAccountEntrySource.supplierSettlement &&
              line.entry.sourceDocumentId == payment.id) {
            originalFinancialEntry = line.entry;
            break;
          }
        }
        if (originalFinancialEntry == null) {
          throw StateError(
              'Financial entry for this supplier payment was not found.');
        }
        final financialReversal = await financialRepository.createEntry(
          accountId: payment.financialAccountId!,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: payment.amountQirsh,
          sourceType: FinancialAccountEntrySource.cancellationReversal,
          sourceDocumentId: cancellationId,
          effectiveDate: now,
          createdByUserId: user.id,
          reference: 'عكس دفعة المورد ${payment.id}',
          note: cleanReason,
          reversalOf: originalFinancialEntry.id,
          paymentMethod: payment.paymentMethod,
        );
        financialReversalEntryId = financialReversal.id;
      }

      final cancellation = SupplierPaymentCancellation(
        id: cancellationId,
        originalPaymentId: payment.id,
        cancelledAt: now,
        cancelledByUserId: user.id,
        reason: cleanReason,
        supplierLedgerReversalEntryId: ledgerReversal.id,
        financialAccountReversalEntryId: financialReversalEntryId,
      );
      _payments[index] = SupplierPaymentRecord(
        id: payment.id,
        supplierId: payment.supplierId,
        date: payment.date,
        amountQirsh: payment.amountQirsh,
        createdAt: payment.createdAt,
        createdByUserId: payment.createdByUserId,
        createdByUserName: payment.createdByUserName,
        notes: payment.notes,
        financialAccountId: payment.financialAccountId,
        paymentMethod: payment.paymentMethod,
        cancellation: cancellation,
      );
      _cancellationRequestIds[requestId] = cancellationId;
      await _recordAudit(
        actionType: 'supplier.payment.reversed',
        descriptionAr: 'تم عكس دفعة المورد ${supplier.name}.',
        referenceId: cancellationId,
      );
      return cancellation;
    });
  }

  @override
  Future<SupplierAccountEntry> reversePurchaseEntry({
    required PurchaseIntake cancelledPurchase,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final userId =
        _normalizedRequiredId(cancelledByUserId, 'cancelledByUserId');
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
    final paymentAmount =
        originalEntry.debitAmountQirsh - balanceBeforeReversal;
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
      descriptionAr: 'إلغاء مشتريات من المورد ${supplier.name}: $reason',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(reversalEntry);
    _entries.add(reversalEntry);
    await _recordAudit(
      actionType: 'supplier.purchase.reversed',
      descriptionAr: 'تم عكس قيد مشتريات المورد ${supplier.name}.',
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
    _paymentRequestFingerprints.clear();
    _cancellationRequestIds.clear();
    _generatedEntryIdCounter = 0;
    _generatedPaymentIdCounter = 0;
    _generatedCancellationIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    final ownState = ObjectStateSnapshot<
        (
          List<SupplierAccountEntry>,
          List<SupplierPaymentRecord>,
          Map<String, String>,
          Map<String, String>,
          int,
          int,
          int
        )>(
      captureState: () => (
        List<SupplierAccountEntry>.from(_entries),
        List<SupplierPaymentRecord>.from(_payments),
        Map<String, String>.from(_paymentRequestFingerprints),
        Map<String, String>.from(_cancellationRequestIds),
        _generatedEntryIdCounter,
        _generatedPaymentIdCounter,
        _generatedCancellationIdCounter,
      ),
      restoreState: (state) {
        _entries
          ..clear()
          ..addAll(state.$1);
        _payments
          ..clear()
          ..addAll(state.$2);
        _paymentRequestFingerprints
          ..clear()
          ..addAll(state.$3);
        _cancellationRequestIds
          ..clear()
          ..addAll(state.$4);
        _generatedEntryIdCounter = state.$5;
        _generatedPaymentIdCounter = state.$6;
        _generatedCancellationIdCounter = state.$7;
      },
    );
    if (_auditLogRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Ù…Ø³ØªÙˆØ¯Ø¹ Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚ Ù„Ø§ ÙŠØ¯Ø¹Ù… Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ø§Ù„Ø°Ø±ÙŠØ©.');
    }
    return CompositeSnapshot([
      ownState,
      (_auditLogRepository as TransactionSnapshotProvider)
          .createTransactionSnapshot(),
    ]);
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

  String _paymentFingerprint(SupplierPaymentDraft draft) {
    return [
      draft.supplierId.trim(),
      draft.date.toUtc().toIso8601String(),
      draft.amountQirsh,
      draft.createdByUserId.trim(),
      draft.financialAccountId?.trim() ?? '',
      draft.paymentMethod?.name ?? '',
      draft.negativeBalanceApprovalId?.trim() ?? '',
    ].join('|');
  }

  String _normalizedRequiredText(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
    return normalized;
  }

  void _requireOwner(AppUser user) {
    if (!user.canProceed || user.role != UserRole.owner) {
      throw StateError(
          'Supplier payment cancellation is available to the owner only.');
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

  String _generateCancellationId(DateTime now) {
    _generatedCancellationIdCounter++;
    return 'spc-${now.microsecondsSinceEpoch}-$_generatedCancellationIdCounter';
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
    await _auditLogRepository.record(
      AuditLogDraft(
        actionType: actionType,
        descriptionAr: descriptionAr,
        referenceId: referenceId,
      ),
    );
  }
}
