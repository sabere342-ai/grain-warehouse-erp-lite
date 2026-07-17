import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';

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
  Future<List<SupplierAdvance>> listAdvances();
  Future<List<SupplierAdvanceApplication>> listAdvanceApplications();
  Future<List<SupplierAdvanceRefund>> listAdvanceRefunds();
  Future<int> remainingAdvanceQirsh(String advanceId);
  Future<SupplierAdvanceApplication> applyAdvance(
      SupplierAdvanceApplicationDraft draft);
  Future<SupplierAdvanceRefund> refundAdvance(SupplierAdvanceRefundDraft draft);
  Future<SupplierAdvanceApplication> reverseAdvanceApplication(
      {required AppUser user,
      required String applicationId,
      required String reason,
      required String operationRequestId});
  Future<SupplierAdvanceRefund> reverseAdvanceRefund(
      {required AppUser user,
      required String refundId,
      required String reason,
      required String operationRequestId,
      String? overpaymentApprovalId});
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

abstract class DurableSupplierAccountRepository
    implements SupplierAccountRepository, TransactionSnapshotProvider {
  Future<void> restoreSupplierAccountsIntoEmpty({
    required List<SupplierAccountEntry> entries,
    required List<SupplierPaymentRecord> payments,
    List<SupplierAdvance> advances = const [],
    List<SupplierAdvanceApplication> applications = const [],
    List<SupplierAdvanceRefund> refunds = const [],
  });

  Future<void> clearForOwnerDataWipe();
}

class LocalSupplierAccountRepository
    implements DurableSupplierAccountRepository {
  LocalSupplierAccountRepository({
    required SupplierRepository supplierRepository,
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
    NegativeBalanceApprovalService? negativeBalanceApprovalService,
  })  : _supplierRepository = supplierRepository,
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository,
        _negativeBalanceApprovalService = negativeBalanceApprovalService;

  final SupplierRepository _supplierRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final NegativeBalanceApprovalService? _negativeBalanceApprovalService;
  final List<SupplierAccountEntry> _entries = [];
  final List<SupplierPaymentRecord> _payments = [];
  final List<SupplierAdvance> _advances = [];
  final List<SupplierAdvanceApplication> _advanceApplications = [];
  final List<SupplierAdvanceRefund> _advanceRefunds = [];
  final Map<String, String> _paymentRequestFingerprints = {};
  final Map<String, String> _cancellationRequestIds = {};
  final Map<String, String> _advanceRequestFingerprints = {};
  int _generatedEntryIdCounter = 0;
  int _generatedPaymentIdCounter = 0;
  int _generatedCancellationIdCounter = 0;
  int _generatedAdvanceIdCounter = 0;
  int _generatedAdvanceApplicationIdCounter = 0;
  int _generatedAdvanceRefundIdCounter = 0;

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
    final settledAmountQirsh = balance <= 0
        ? 0
        : draft.amountQirsh < balance
            ? draft.amountQirsh
            : balance;
    final advanceAmountQirsh = draft.amountQirsh - settledAmountQirsh;
    if (advanceAmountQirsh > 0) {
      if (_normalizedOptionalText(draft.financialAccountId) == null ||
          _normalizedOptionalText(draft.operationRequestId) == null ||
          _normalizedOptionalText(draft.overpaymentApprovalId) == null) {
        throw StateError(
            'Supplier overpayment requires account, request id, and owner approval.');
      }
      if (_negativeBalanceApprovalService == null) {
        throw StateError(
            'Supplier advance approval service is not configured.');
      }
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
      settledAmountQirsh: settledAmountQirsh,
      advanceAmountQirsh: advanceAmountQirsh,
      operationRequestId: _normalizedOptionalText(draft.operationRequestId),
      operationRequestFingerprint: _paymentFingerprint(draft),
    );
    _validatePayment(payment);

    final entry = settledAmountQirsh == 0
        ? null
        : SupplierAccountEntry(
            id: _generateEntryId(now),
            supplierId: supplier.id,
            date: payment.date,
            type: SupplierAccountEntryType.payment,
            debitAmountQirsh: 0,
            creditAmountQirsh: settledAmountQirsh,
            sourceDocumentType: 'supplierPayment',
            sourceDocumentId: payment.id,
            descriptionAr: 'مدفوع للمورد ${supplier.name}',
            createdAt: now,
            createdByUserId: payment.createdByUserId,
          );
    if (entry != null) _validateEntry(entry);

    final advance = advanceAmountQirsh == 0
        ? null
        : SupplierAdvance(
            id: _generateAdvanceId(now),
            supplierId: supplier.id,
            sourcePaymentId: payment.id,
            financialAccountId: payment.financialAccountId!.trim(),
            amountQirsh: advanceAmountQirsh,
            createdAt: now,
            createdByUserId: payment.createdByUserId,
            ownerApprovalId: draft.overpaymentApprovalId!.trim(),
            paymentMethod: payment.paymentMethod,
            operationRequestId: draft.operationRequestId!.trim(),
          );

    final requestId = _normalizedOptionalText(draft.operationRequestId);
    final requestFingerprint = _paymentFingerprint(draft);

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    if (_financialAccountRepository is TransactionSnapshotProvider) {
      snapshots.add((_financialAccountRepository as TransactionSnapshotProvider)
          .createTransactionSnapshot());
    }
    final approvalService = _negativeBalanceApprovalService;
    if (advance != null) {
      snapshots.add(approvalService!.createTransactionSnapshot());
    }
    return RepositoryTransaction.execute(snapshots, () async {
      NegativeBalanceApprovalBinding? advanceApprovalBinding;
      NegativeBalanceApprovalConsumption? advanceAuthorization;
      if (requestId != null &&
          _paymentRequestFingerprints.containsKey(requestId)) {
        throw StateError('Supplier payment request was already processed.');
      }
      final lockedBalance = await balanceForSupplier(supplier.id);
      final lockedSettled = lockedBalance <= 0
          ? 0
          : draft.amountQirsh < lockedBalance
              ? draft.amountQirsh
              : lockedBalance;
      if (lockedSettled != settledAmountQirsh) {
        throw StateError('Supplier balance changed; retry the payment.');
      }
      if (advance != null) {
        final financialRepository = _financialAccountRepository!;
        final accountBalance = await financialRepository
            .currentBalanceForAccount(advance.financialAccountId);
        advanceApprovalBinding = NegativeBalanceApprovalBinding(
          approvalId: advance.ownerApprovalId,
          transactionId: payment.id,
          accountId: advance.financialAccountId,
          amountQirsh: advance.amountQirsh,
          operationType: NegativeBalanceOperationType.supplierOverpayment,
          sourceDocumentId: requestId!,
          sourceDocumentType: 'supplierOverpayment',
          requestedByUserId: payment.createdByUserId,
          balanceBeforeQirsh: accountBalance,
          expectedBalanceAfterQirsh: accountBalance - payment.amountQirsh,
        );
        advanceAuthorization = await approvalService!.consume(
          advanceApprovalBinding,
        );
      }
      _payments.add(payment);
      if (entry != null) _entries.add(entry);
      if (advance != null) _advances.add(advance);
      await _recordAudit(
        actionType: 'supplier.payment.recorded',
        descriptionAr: 'تم تسجيل دفع للمورد ${supplier.name}.',
        referenceId: payment.id,
      );

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          payment.financialAccountId != null &&
          payment.financialAccountId!.isNotEmpty) {
        if (advanceAuthorization != null) {
          await faRepo.createSupplierOverpaymentEntry(
            accountId: payment.financialAccountId!,
            amountQirsh: payment.amountQirsh,
            sourceDocumentId: payment.id,
            effectiveDate: payment.date,
            createdByUserId: payment.createdByUserId,
            reference: 'ØªØ³ÙˆÙŠØ© Ù…Ø¹ Ø§Ù„Ù…ÙˆØ±Ø¯ ${supplier.name}',
            note: 'Ø¯ÙØ¹ Ù„Ù„Ù…ÙˆØ±Ø¯ ${payment.amountQirsh} Ù‚ÙŠØ±Ø´',
            paymentMethod: payment.paymentMethod,
            authorization: advanceAuthorization,
          );
        } else {
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
            negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
            approvalSourceDocumentId: draft.operationRequestId,
          );
        }
      }

      if (requestId != null) {
        _paymentRequestFingerprints[requestId] = requestFingerprint;
        _advanceRequestFingerprints[requestId] = requestFingerprint;
      }

      return payment;
    });
  }

  @override
  Future<List<SupplierAdvance>> listAdvances() async =>
      List<SupplierAdvance>.unmodifiable(_advances);

  @override
  Future<List<SupplierAdvanceApplication>> listAdvanceApplications() async =>
      List<SupplierAdvanceApplication>.unmodifiable(_advanceApplications);

  @override
  Future<List<SupplierAdvanceRefund>> listAdvanceRefunds() async =>
      List<SupplierAdvanceRefund>.unmodifiable(_advanceRefunds);

  @override
  Future<int> remainingAdvanceQirsh(String advanceId) async {
    final id = _normalizedRequiredId(advanceId, 'advanceId');
    final advance = _advanceById(id);
    if (advance.isReversed) return 0;
    final applied = _advanceApplications
        .where((value) => value.advanceId == id && !value.isReversed)
        .fold<int>(0, (total, value) => total + value.amountQirsh);
    final refunded = _advanceRefunds
        .where((value) => value.advanceId == id && !value.isReversed)
        .fold<int>(0, (total, value) => total + value.amountQirsh);
    return advance.amountQirsh - applied - refunded;
  }

  @override
  Future<SupplierAdvanceApplication> applyAdvance(
      SupplierAdvanceApplicationDraft draft) async {
    final advance =
        _advanceById(_normalizedRequiredId(draft.advanceId, 'advanceId'));
    final supplierId = _normalizedRequiredId(draft.supplierId, 'supplierId');
    final requestId =
        _normalizedRequiredId(draft.operationRequestId, 'operationRequestId');
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(draft.amountQirsh, 'amountQirsh');
    }
    if (advance.supplierId != supplierId || advance.isReversed) {
      throw StateError('Advance does not belong to the active supplier.');
    }
    return RepositoryTransaction.execute(
        <SnapshotHolder>[createTransactionSnapshot()], () async {
      final fingerprint =
          'apply|${draft.advanceId}|$supplierId|${draft.amountQirsh}|${draft.date.toUtc().toIso8601String()}';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceApplications
            .firstWhere((value) => value.operationRequestId == requestId);
      }
      if (await balanceForSupplier(supplierId) < draft.amountQirsh ||
          await remainingAdvanceQirsh(advance.id) < draft.amountQirsh) {
        throw StateError(
            'Advance application exceeds its available amount or supplier payable.');
      }
      final now = DateTime.now();
      final entry = SupplierAccountEntry(
        id: _generateEntryId(now),
        supplierId: supplierId,
        date: draft.date,
        type: SupplierAccountEntryType.advanceApplication,
        debitAmountQirsh: 0,
        creditAmountQirsh: draft.amountQirsh,
        sourceDocumentType: 'supplierAdvanceApplication',
        sourceDocumentId: requestId,
        descriptionAr: 'تطبيق سلفة المورد',
        createdAt: now,
        createdByUserId: draft.createdByUserId.trim(),
      );
      _validateEntry(entry);
      final application = SupplierAdvanceApplication(
        id: _generateAdvanceApplicationId(now),
        advanceId: advance.id,
        supplierId: supplierId,
        amountQirsh: draft.amountQirsh,
        appliedAt: now,
        createdByUserId: draft.createdByUserId.trim(),
        operationRequestId: requestId,
        supplierLedgerEntryId: entry.id,
      );
      _entries.add(entry);
      _advanceApplications.add(application);
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'supplier.advance.applied',
          descriptionAr: 'تم تطبيق سلفة المورد.',
          referenceId: application.id);
      return application;
    });
  }

  @override
  Future<SupplierAdvanceRefund> refundAdvance(
      SupplierAdvanceRefundDraft draft) async {
    final advance =
        _advanceById(_normalizedRequiredId(draft.advanceId, 'advanceId'));
    final requestId =
        _normalizedRequiredId(draft.operationRequestId, 'operationRequestId');
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(draft.amountQirsh, 'amountQirsh');
    }
    final accountId = _normalizedOptionalText(draft.financialAccountId) ??
        advance.financialAccountId;
    if (accountId != advance.financialAccountId) {
      throw StateError(
          'Supplier refund must use the original financial account.');
    }
    final financialRepository = _financialAccountRepository ??
        (throw StateError(
            'Financial account repository is required and must be transaction-safe.'));
    if (financialRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Financial account repository is required and must be transaction-safe.');
    }
    final snapshotProvider = financialRepository as TransactionSnapshotProvider;
    return RepositoryTransaction.execute(<SnapshotHolder>[
      createTransactionSnapshot(),
      snapshotProvider.createTransactionSnapshot()
    ], () async {
      final fingerprint =
          'refund|${draft.advanceId}|${draft.amountQirsh}|$accountId|${draft.date.toUtc().toIso8601String()}';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceRefunds
            .firstWhere((value) => value.operationRequestId == requestId);
      }
      if (advance.isReversed ||
          await remainingAdvanceQirsh(advance.id) < draft.amountQirsh) {
        throw StateError('Refund exceeds available supplier advance.');
      }
      final now = DateTime.now();
      final financialEntry = await financialRepository.createEntry(
        accountId: accountId,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: draft.amountQirsh,
        sourceType: FinancialAccountEntrySource.supplierAdvanceRefund,
        sourceDocumentId: requestId,
        effectiveDate: draft.date,
        createdByUserId: draft.createdByUserId.trim(),
        paymentMethod: draft.paymentMethod ?? advance.paymentMethod,
        reference: 'استرداد سلفة من المورد',
      );
      final refund = SupplierAdvanceRefund(
        id: _generateAdvanceRefundId(now),
        advanceId: advance.id,
        supplierId: advance.supplierId,
        financialAccountId: accountId,
        amountQirsh: draft.amountQirsh,
        refundedAt: now,
        createdByUserId: draft.createdByUserId.trim(),
        operationRequestId: requestId,
        financialEntryId: financialEntry.id,
      );
      _advanceRefunds.add(refund);
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'supplier.advance.refunded',
          descriptionAr: 'تم استرداد سلفة من المورد.',
          referenceId: refund.id);
      return refund;
    });
  }

  @override
  Future<SupplierAdvanceApplication> reverseAdvanceApplication(
      {required AppUser user,
      required String applicationId,
      required String reason,
      required String operationRequestId}) async {
    _requireOwner(user);
    final id = _normalizedRequiredId(applicationId, 'applicationId');
    final cleanReason = _normalizedRequiredText(reason, 'reason');
    final requestId =
        _normalizedRequiredId(operationRequestId, 'operationRequestId');
    return RepositoryTransaction.execute(
        <SnapshotHolder>[createTransactionSnapshot()], () async {
      final applicationIndex =
          _advanceApplications.indexWhere((value) => value.id == id);
      if (applicationIndex < 0) {
        throw StateError('Supplier advance application was not found.');
      }
      final application = _advanceApplications[applicationIndex];
      final fingerprint = 'supplier|reverse-application|$id|$cleanReason';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceApplications[applicationIndex];
      }
      final advance = _advanceById(application.advanceId);
      if (advance.isReversed) {
        throw StateError('Supplier advance source is reversed.');
      }
      if (application.isReversed) {
        throw StateError('Supplier advance application was already reversed.');
      }
      final now = DateTime.now();
      final entry = SupplierAccountEntry(
        id: _generateEntryId(now),
        supplierId: application.supplierId,
        date: now,
        type: SupplierAccountEntryType.advanceApplicationReversal,
        debitAmountQirsh: application.amountQirsh,
        creditAmountQirsh: 0,
        sourceDocumentType: 'supplierAdvanceApplicationReversal',
        sourceDocumentId: application.id,
        descriptionAr: 'Supplier advance application reversal: $cleanReason',
        createdAt: now,
        createdByUserId: user.id,
      );
      _validateEntry(entry);
      _entries.add(entry);
      _advanceApplications[applicationIndex] = SupplierAdvanceApplication(
        id: application.id,
        advanceId: application.advanceId,
        supplierId: application.supplierId,
        amountQirsh: application.amountQirsh,
        appliedAt: application.appliedAt,
        createdByUserId: application.createdByUserId,
        operationRequestId: application.operationRequestId,
        supplierLedgerEntryId: application.supplierLedgerEntryId,
        reversedAt: now,
        reversedByUserId: user.id,
        reversalReason: cleanReason,
        reversalLedgerEntryId: entry.id,
      );
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'supplier.advance.application.reversed',
          descriptionAr: 'Supplier advance application reversed.',
          referenceId: application.id);
      return _advanceApplications[applicationIndex];
    });
  }

  @override
  Future<SupplierAdvanceRefund> reverseAdvanceRefund(
      {required AppUser user,
      required String refundId,
      required String reason,
      required String operationRequestId,
      String? overpaymentApprovalId}) async {
    _requireOwner(user);
    final id = _normalizedRequiredId(refundId, 'refundId');
    final cleanReason = _normalizedRequiredText(reason, 'reason');
    final requestId =
        _normalizedRequiredId(operationRequestId, 'operationRequestId');
    final financialRepository = _financialAccountRepository ??
        (throw StateError('Financial account repository is required.'));
    if (financialRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Financial account repository must be transaction-safe.');
    }
    final snapshotProvider = financialRepository as TransactionSnapshotProvider;
    return RepositoryTransaction.execute(<SnapshotHolder>[
      createTransactionSnapshot(),
      snapshotProvider.createTransactionSnapshot()
    ], () async {
      final refundIndex = _advanceRefunds.indexWhere((value) => value.id == id);
      if (refundIndex < 0) {
        throw StateError('Supplier advance refund was not found.');
      }
      final refund = _advanceRefunds[refundIndex];
      final fingerprint = 'supplier|reverse-refund|$id|$cleanReason';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceRefunds[refundIndex];
      }
      if (refund.isReversed) {
        throw StateError('Supplier advance refund was already reversed.');
      }
      final advance = _advanceById(refund.advanceId);
      if (advance.isReversed) {
        throw StateError('Supplier advance source is reversed.');
      }
      final originalFinancialStatement = await financialRepository
          .statementForAccount(refund.financialAccountId);
      FinancialAccountEntry? originalEntry;
      for (final line in originalFinancialStatement.lines) {
        if (line.entry.sourceDocumentId == refund.operationRequestId &&
            line.entry.sourceType ==
                FinancialAccountEntrySource.supplierAdvanceRefund) {
          originalEntry = line.entry;
          break;
        }
      }
      if (originalEntry == null) {
        throw StateError('Financial entry for this refund was not found.');
      }
      final currentBalance = await financialRepository
          .currentBalanceForAccount(refund.financialAccountId);
      if (currentBalance - refund.amountQirsh < 0 &&
          overpaymentApprovalId?.trim().isNotEmpty != true) {
        throw StateError('SUPPLIER_REFUND_REVERSAL_APPROVAL_REQUIRED');
      }
      final now = DateTime.now();
      final reversalEntry = await financialRepository.createEntry(
        accountId: refund.financialAccountId,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: refund.amountQirsh,
        sourceType: FinancialAccountEntrySource.supplierAdvanceRefundReversal,
        sourceDocumentId: refund.id,
        effectiveDate: now,
        createdByUserId: user.id,
        reversalOf: originalEntry.id,
        reference: 'Supplier advance refund reversal',
        note: cleanReason,
        negativeBalanceApprovalId: overpaymentApprovalId,
        approvalSourceDocumentId: requestId,
        approvalAuthorizationContext:
            NegativeBalanceApprovalContext.supplierAdvanceRefundReversal(
          supplierId: refund.supplierId,
          advanceId: refund.advanceId,
          refundId: refund.id,
        ),
      );
      _advanceRefunds[refundIndex] = SupplierAdvanceRefund(
        id: refund.id,
        advanceId: refund.advanceId,
        supplierId: refund.supplierId,
        financialAccountId: refund.financialAccountId,
        amountQirsh: refund.amountQirsh,
        refundedAt: refund.refundedAt,
        createdByUserId: refund.createdByUserId,
        operationRequestId: refund.operationRequestId,
        financialEntryId: refund.financialEntryId,
        reversedAt: now,
        reversedByUserId: user.id,
        reversalReason: cleanReason,
        reversalFinancialEntryId: reversalEntry.id,
      );
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'supplier.advance.refund.reversed',
          descriptionAr: 'Supplier advance refund reversed.',
          referenceId: refund.id);
      return _advanceRefunds[refundIndex];
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
      final sourceAdvanceIndex = _advances.indexWhere(
        (advance) => advance.sourcePaymentId == payment.id,
      );
      if (sourceAdvanceIndex >= 0) {
        final advance = _advances[sourceAdvanceIndex];
        final hasActiveDependents = _advanceApplications.any(
              (value) => value.advanceId == advance.id && !value.isReversed,
            ) ||
            _advanceRefunds.any(
              (value) => value.advanceId == advance.id && !value.isReversed,
            );
        if (hasActiveDependents) {
          throw StateError(
              'Supplier advance source cannot be reversed while active applications or refunds exist.');
        }
        _advances[sourceAdvanceIndex] = SupplierAdvance(
          id: advance.id,
          supplierId: advance.supplierId,
          sourcePaymentId: advance.sourcePaymentId,
          financialAccountId: advance.financialAccountId,
          amountQirsh: advance.amountQirsh,
          createdAt: advance.createdAt,
          createdByUserId: advance.createdByUserId,
          ownerApprovalId: advance.ownerApprovalId,
          operationRequestId: advance.operationRequestId,
          paymentMethod: advance.paymentMethod,
          reversedAt: DateTime.now(),
          reversedByUserId: user.id,
        );
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
        debitAmountQirsh: payment.settledAmountQirsh ?? payment.amountQirsh,
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
        operationRequestId: requestId,
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
        settledAmountQirsh: payment.settledAmountQirsh,
        advanceAmountQirsh: payment.advanceAmountQirsh,
        operationRequestId: payment.operationRequestId,
        operationRequestFingerprint: payment.operationRequestFingerprint,
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

  @override
  Future<void> restoreSupplierAccountsIntoEmpty({
    required List<SupplierAccountEntry> entries,
    required List<SupplierPaymentRecord> payments,
    List<SupplierAdvance> advances = const [],
    List<SupplierAdvanceApplication> applications = const [],
    List<SupplierAdvanceRefund> refunds = const [],
  }) async {
    if (_entries.isNotEmpty ||
        _payments.isNotEmpty ||
        _advances.isNotEmpty ||
        _advanceApplications.isNotEmpty ||
        _advanceRefunds.isNotEmpty) {
      throw StateError('Supplier account repository is not empty.');
    }
    _validateUniqueRestoredEntries(entries);
    _validateUniqueRestoredPayments(payments);
    _entries.addAll(entries);
    _payments.addAll(payments);
    for (final payment in payments) {
      final requestId = _normalizedOptionalText(payment.operationRequestId);
      final fingerprint =
          _normalizedOptionalText(payment.operationRequestFingerprint);
      if (requestId != null && fingerprint != null) {
        if (_paymentRequestFingerprints.containsKey(requestId)) {
          throw StateError('Duplicate supplier payment request id.');
        }
        _paymentRequestFingerprints[requestId] = fingerprint;
      }
      final cancellationRequestId =
          _normalizedOptionalText(payment.cancellation?.operationRequestId);
      if (cancellationRequestId != null) {
        if (_cancellationRequestIds.containsKey(cancellationRequestId)) {
          throw StateError('Duplicate supplier cancellation request id.');
        }
        _cancellationRequestIds[cancellationRequestId] =
            payment.cancellation!.id;
      }
    }
    _validateRestoredAdvances(advances, applications, refunds);
    _advances.addAll(advances);
    _advanceApplications.addAll(applications);
    _advanceRefunds.addAll(refunds);
    for (final value in [
      ...advances.map((v) => v.operationRequestId),
      ...applications.map((v) => v.operationRequestId),
      ...refunds.map((v) => v.operationRequestId)
    ]) {
      _advanceRequestFingerprints[value] = 'restored:$value';
    }
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _entries.clear();
    _payments.clear();
    _advances.clear();
    _advanceApplications.clear();
    _advanceRefunds.clear();
    _paymentRequestFingerprints.clear();
    _cancellationRequestIds.clear();
    _advanceRequestFingerprints.clear();
    _generatedEntryIdCounter = 0;
    _generatedPaymentIdCounter = 0;
    _generatedCancellationIdCounter = 0;
    _generatedAdvanceIdCounter = 0;
    _generatedAdvanceApplicationIdCounter = 0;
    _generatedAdvanceRefundIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    final advanceState = ObjectStateSnapshot<
        (
          List<SupplierAdvance>,
          List<SupplierAdvanceApplication>,
          List<SupplierAdvanceRefund>,
          Map<String, String>,
          int,
          int,
          int
        )>(
      captureState: () => (
        List<SupplierAdvance>.from(_advances),
        List<SupplierAdvanceApplication>.from(_advanceApplications),
        List<SupplierAdvanceRefund>.from(_advanceRefunds),
        Map<String, String>.from(_advanceRequestFingerprints),
        _generatedAdvanceIdCounter,
        _generatedAdvanceApplicationIdCounter,
        _generatedAdvanceRefundIdCounter,
      ),
      restoreState: (state) {
        _advances
          ..clear()
          ..addAll(state.$1);
        _advanceApplications
          ..clear()
          ..addAll(state.$2);
        _advanceRefunds
          ..clear()
          ..addAll(state.$3);
        _advanceRequestFingerprints
          ..clear()
          ..addAll(state.$4);
        _generatedAdvanceIdCounter = state.$5;
        _generatedAdvanceApplicationIdCounter = state.$6;
        _generatedAdvanceRefundIdCounter = state.$7;
      },
    );
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
      advanceState,
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

  void _validateRestoredAdvances(
    List<SupplierAdvance> advances,
    List<SupplierAdvanceApplication> applications,
    List<SupplierAdvanceRefund> refunds,
  ) {
    final ids = <String>{};
    for (final value in advances) {
      if (!value.hasValidId || value.amountQirsh <= 0 || !ids.add(value.id)) {
        throw StateError('Invalid or duplicate supplier advance.');
      }
    }
    final sourceIds = advances.map((value) => value.id).toSet();
    for (final value in applications) {
      if (!value.hasValidId ||
          value.amountQirsh <= 0 ||
          !sourceIds.contains(value.advanceId)) {
        throw StateError('Orphan or invalid supplier advance operation.');
      }
    }
    for (final value in refunds) {
      if (!value.hasValidId ||
          value.amountQirsh <= 0 ||
          !sourceIds.contains(value.advanceId)) {
        throw StateError('Orphan or invalid supplier advance operation.');
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

  String _generateAdvanceId(DateTime now) {
    _generatedAdvanceIdCounter++;
    return 'sad-${now.microsecondsSinceEpoch}-$_generatedAdvanceIdCounter';
  }

  String _generateAdvanceApplicationId(DateTime now) {
    _generatedAdvanceApplicationIdCounter++;
    return 'saa-${now.microsecondsSinceEpoch}-$_generatedAdvanceApplicationIdCounter';
  }

  String _generateAdvanceRefundId(DateTime now) {
    _generatedAdvanceRefundIdCounter++;
    return 'sar-${now.microsecondsSinceEpoch}-$_generatedAdvanceRefundIdCounter';
  }

  SupplierAdvance _advanceById(String id) {
    for (final advance in _advances) {
      if (advance.id == id) return advance;
    }
    throw StateError('Supplier advance was not found.');
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
