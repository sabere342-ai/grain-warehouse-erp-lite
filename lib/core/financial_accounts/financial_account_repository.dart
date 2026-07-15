import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';

abstract class FinancialAccountRepository {
  Future<List<FinancialAccount>> listAccounts({bool includeInactive = false});
  Future<FinancialAccount> createAccount(FinancialAccountDraft draft);
  Future<void> deactivateAccount(String accountId, String deactivatedByUserId);
  Future<void> reactivateAccount(String accountId, String reactivatedByUserId);
  Future<FinancialAccount> accountById(String accountId);
  Future<int> currentBalanceForAccount(String accountId);
  Future<List<FinancialAccountBalanceSummary>> allAccountBalances({
    bool includeInactive = false,
  });
  Future<FinancialAccountStatement> statementForAccount(
    String accountId, {
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<void> updateAccountPolicy({
    required String accountId,
    required bool allowNegativeBalance,
    required String updatedByUserId,
  });
  Future<void> setOpeningBalance({
    required String accountId,
    required int amountQirsh,
    required DateTime effectiveDate,
    required String createdByUserId,
  });
  Future<void> correctOpeningBalance(OpeningBalanceCorrectionDraft draft);
  Future<bool> accountHasEntries(String accountId);
  Future<FinancialAccountEntry> createEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amountQirsh,
    required FinancialAccountEntrySource sourceType,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    String? sourceDocumentNumber,
    String? reference,
    String? note,
    String? reversalOf,
    String? correctionGroup,
    PaymentMethod? paymentMethod,
    String? approvedByUserId,
    String? negativeBalanceApprovalId,
    String? approvalSourceDocumentId,
  });
  Future<FinancialAccountEntry> createSupplierOverpaymentEntry({
    required String accountId,
    required int amountQirsh,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required NegativeBalanceApprovalConsumption authorization,
    String? reference,
    String? note,
    PaymentMethod? paymentMethod,
  });
  Future<FinancialTransfer> createTransfer(
      {required AppUser user, required FinancialTransferDraft draft});
  Future<FinancialTransfer> reverseTransfer({
    required AppUser user,
    required String transferId,
    required String reason,
  });
  Future<List<FinancialTransfer>> listTransfers();
  Future<List<FinancialClosing>> listClosings();
  Future<FinancialClosing> createClosing(
      {required AppUser user, required FinancialClosingDraft draft});
  Future<FinancialClosing> reopenClosing(
      {required AppUser user,
      required String closingId,
      required String reason});
}

class LocalFinancialAccountRepository
    implements FinancialAccountRepository, TransactionSnapshotProvider {
  LocalFinancialAccountRepository({
    AuditLogRepository? auditLogRepository,
    NegativeBalanceApprovalService? negativeBalanceApprovalService,
  })  : _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _negativeBalanceApprovalService = negativeBalanceApprovalService;

  final AuditLogRepository _auditLogRepository;
  final NegativeBalanceApprovalService? _negativeBalanceApprovalService;
  final List<FinancialAccount> _accounts = [];
  final List<FinancialAccountEntry> _entries = [];
  final List<FinancialTransfer> _transfers = [];
  final List<FinancialClosing> _closings = [];
  int _generatedAccountIdCounter = 0;
  int _generatedEntryIdCounter = 0;
  int _generatedTransferIdCounter = 0;

  @override
  Future<List<FinancialAccount>> listAccounts({
    bool includeInactive = false,
  }) async {
    final filtered = includeInactive
        ? [..._accounts]
        : _accounts.where((a) => a.isActive).toList(growable: false);
    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<FinancialAccount>.unmodifiable(filtered);
  }

  @override
  Future<FinancialAccount> createAccount(FinancialAccountDraft draft) async {
    _validateDraft(draft);
    final name = draft.name.trim();
    final activeWithSameName = _accounts.where(
      (a) => a.isActive && a.name == name,
    );
    if (activeWithSameName.isNotEmpty) {
      throw StateError('يوجد حساب نشط بنفس الاسم.');
    }

    final now = DateTime.now();
    final account = FinancialAccount(
      id: _generateAccountId(now),
      name: name,
      type: draft.type,
      allowNegativeBalance: draft.allowNegativeBalance,
      referenceInfo: _normalizedOptionalText(draft.referenceInfo),
      notes: _normalizedOptionalText(draft.notes),
      createdByUserId: draft.createdByUserId.trim(),
      createdAt: now,
    );
    _accounts.add(account);
    await _recordAudit(
      actionType: 'financial_account.created',
      descriptionAr: 'تم إنشاء حساب "${account.name}".',
      referenceId: account.id,
    );
    return account;
  }

  @override
  Future<void> deactivateAccount(
    String accountId,
    String deactivatedByUserId,
  ) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    _normalizedRequiredId(deactivatedByUserId, 'deactivatedByUserId');
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw StateError('الحساب غير موجود.');
    }
    final account = _accounts[index];
    if (!account.isActive) {
      throw StateError('الحساب معطّل بالفعل.');
    }

    _accounts[index] = FinancialAccount(
      id: account.id,
      name: account.name,
      type: account.type,
      isActive: false,
      allowNegativeBalance: account.allowNegativeBalance,
      openingBalanceQirsh: account.openingBalanceQirsh,
      openingBalanceDate: account.openingBalanceDate,
      referenceInfo: account.referenceInfo,
      notes: account.notes,
      createdByUserId: account.createdByUserId,
      createdAt: account.createdAt,
    );
    await _recordAudit(
      actionType: 'financial_account.deactivated',
      descriptionAr: 'تم تعطيل حساب "${account.name}".',
      referenceId: account.id,
    );
  }

  @override
  Future<void> reactivateAccount(
    String accountId,
    String reactivatedByUserId,
  ) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw StateError('الحساب غير موجود.');
    }
    final account = _accounts[index];
    if (account.isActive) {
      throw StateError('الحساب نشط بالفعل.');
    }

    final name = account.name;
    final activeWithSameName = _accounts.where(
      (a) => a.isActive && a.name == name && a.id != id,
    );
    if (activeWithSameName.isNotEmpty) {
      throw StateError('يوجد حساب نشط بنفس الاسم.');
    }

    _accounts[index] = FinancialAccount(
      id: account.id,
      name: account.name,
      type: account.type,
      isActive: true,
      allowNegativeBalance: account.allowNegativeBalance,
      openingBalanceQirsh: account.openingBalanceQirsh,
      openingBalanceDate: account.openingBalanceDate,
      referenceInfo: account.referenceInfo,
      notes: account.notes,
      createdByUserId: account.createdByUserId,
      createdAt: account.createdAt,
    );
    await _recordAudit(
      actionType: 'financial_account.reactivated',
      descriptionAr: 'تم تنشيط حساب "${account.name}".',
      referenceId: account.id,
    );
  }

  @override
  Future<void> updateAccountPolicy({
    required String accountId,
    required bool allowNegativeBalance,
    required String updatedByUserId,
  }) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    _normalizedRequiredId(updatedByUserId, 'updatedByUserId');
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw StateError('الحساب غير موجود.');
    }
    final account = _accounts[index];
    if (account.allowNegativeBalance == allowNegativeBalance) {
      return;
    }

    _accounts[index] = FinancialAccount(
      id: account.id,
      name: account.name,
      type: account.type,
      isActive: account.isActive,
      allowNegativeBalance: allowNegativeBalance,
      openingBalanceQirsh: account.openingBalanceQirsh,
      openingBalanceDate: account.openingBalanceDate,
      referenceInfo: account.referenceInfo,
      notes: account.notes,
      createdByUserId: account.createdByUserId,
      createdAt: account.createdAt,
    );

    final action = allowNegativeBalance ? 'تفعيل' : 'تعطيل';
    await _recordAudit(
      actionType: 'financial_account.negative_balance_policy.updated',
      descriptionAr:
          'تم $action السماح بالرصيد السالب لحساب "${account.name}".',
      referenceId: account.id,
    );
  }

  @override
  Future<FinancialAccount> accountById(String accountId) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    throw StateError('الحساب غير موجود.');
  }

  @override
  Future<int> currentBalanceForAccount(String accountId) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    await accountById(id);
    var balance = 0;
    for (final entry in _entries.where((e) => e.accountId == id)) {
      balance += entry.signedAmountQirsh;
    }
    return balance;
  }

  @override
  Future<List<FinancialAccountBalanceSummary>> allAccountBalances({
    bool includeInactive = false,
  }) async {
    final accounts = await listAccounts(includeInactive: includeInactive);
    final summaries = <FinancialAccountBalanceSummary>[];
    for (final account in accounts) {
      var balance = 0;
      var count = 0;
      for (final entry in _entries.where((e) => e.accountId == account.id)) {
        balance += entry.signedAmountQirsh;
        count++;
      }
      summaries.add(FinancialAccountBalanceSummary(
        account: account,
        currentBalanceQirsh: balance,
        entryCount: count,
      ));
    }
    return List<FinancialAccountBalanceSummary>.unmodifiable(summaries);
  }

  @override
  Future<FinancialAccountStatement> statementForAccount(
    String accountId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    final account = await accountById(id);

    var accountEntries =
        _entries.where((e) => e.accountId == id).toList(growable: false);
    if (fromDate != null) {
      accountEntries = accountEntries
          .where((e) => !e.effectiveDate.isBefore(fromDate))
          .toList(growable: false);
    }
    if (toDate != null) {
      accountEntries = accountEntries
          .where((e) => !e.effectiveDate.isAfter(toDate))
          .toList(growable: false);
    }
    accountEntries.sort((a, b) {
      final date = a.effectiveDate.compareTo(b.effectiveDate);
      if (date != 0) return date;
      return a.id.compareTo(b.id);
    });

    var running = 0;
    final lines = <FinancialAccountStatementLine>[];
    for (final entry in accountEntries) {
      running += entry.signedAmountQirsh;
      lines.add(FinancialAccountStatementLine(
        entry: entry,
        runningBalanceQirsh: running,
      ));
    }
    return FinancialAccountStatement(
      accountId: id,
      lines: List<FinancialAccountStatementLine>.unmodifiable(lines),
      finalBalanceQirsh: running,
      openingBalanceQirsh: account.openingBalanceQirsh,
    );
  }

  @override
  Future<void> setOpeningBalance({
    required String accountId,
    required int amountQirsh,
    required DateTime effectiveDate,
    required String createdByUserId,
  }) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    final userId = _normalizedRequiredId(createdByUserId, 'createdByUserId');
    final account = await accountById(id);

    final hasEntries = _entries.any((e) => e.accountId == id);
    if (hasEntries) {
      throw StateError(
        'لا يمكن تغيير الرصيد الافتتاحي بعد وجود حركات مالية.',
      );
    }
    if (account.openingBalanceQirsh != 0) {
      throw StateError('الرصيد الافتتاحي مسجل بالفعل.');
    }
    if (amountQirsh <= 0) {
      throw ArgumentError.value(
        amountQirsh,
        'amountQirsh',
        'الرصيد الافتتاحي يجب أن يكون أكبر من صفر.',
      );
    }

    final now = DateTime.now();
    final updatedAccount = FinancialAccount(
      id: account.id,
      name: account.name,
      type: account.type,
      isActive: account.isActive,
      allowNegativeBalance: account.allowNegativeBalance,
      openingBalanceQirsh: amountQirsh,
      openingBalanceDate: effectiveDate,
      referenceInfo: account.referenceInfo,
      notes: account.notes,
      createdByUserId: account.createdByUserId,
      createdAt: account.createdAt,
    );
    final index = _accounts.indexWhere((a) => a.id == id);
    _accounts[index] = updatedAccount;

    final entry = FinancialAccountEntry(
      id: _generateEntryId(now),
      accountId: id,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: amountQirsh,
      sourceType: FinancialAccountEntrySource.openingBalance,
      sourceDocumentId: 'ob-$id',
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: userId,
      note: 'تسجيل الرصيد الافتتاحي',
    );
    _entries.add(entry);

    await _recordAudit(
      actionType: 'financial_account.opening_balance.set',
      descriptionAr:
          'تم تسجيل رصيد افتتاحي $amountQirsh قيرش لحساب "${account.name}".',
      referenceId: account.id,
    );
  }

  @override
  Future<void> correctOpeningBalance(
      OpeningBalanceCorrectionDraft draft) async {
    final id = _normalizedRequiredId(draft.accountId, 'accountId');
    final userId =
        _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    final reason = _normalizedRequiredText(draft.reason, 'reason');
    final account = await accountById(id);

    if (account.openingBalanceQirsh == 0) {
      throw StateError('لا يوجد رصيد افتتاحي لتصحيحه.');
    }
    if (draft.correctedOpeningBalanceQirsh < 0) {
      throw ArgumentError.value(
        draft.correctedOpeningBalanceQirsh,
        'correctedOpeningBalanceQirsh',
        'الرصيد لا يمكن أن يكون سالباً.',
      );
    }

    final now = DateTime.now();
    final correctionGroupId = 'crg-${now.microsecondsSinceEpoch}';

    final originalEntry = FinancialAccountEntry(
      id: _generateEntryId(now),
      accountId: id,
      direction: FinancialAccountEntryDirection.outflow,
      amountQirsh: account.openingBalanceQirsh,
      sourceType: FinancialAccountEntrySource.manualCorrection,
      sourceDocumentId: 'ob-correction-$correctionGroupId',
      effectiveDate: now,
      createdAt: now,
      createdByUserId: userId,
      note: 'تصحيح: حذف الرصيد الافتتاحي القديم',
      correctionGroup: correctionGroupId,
    );

    final correctedEntry = FinancialAccountEntry(
      id: _generateEntryId(now),
      accountId: id,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: draft.correctedOpeningBalanceQirsh,
      sourceType: FinancialAccountEntrySource.manualCorrection,
      sourceDocumentId: 'ob-correction-$correctionGroupId',
      effectiveDate: now,
      createdAt: now,
      createdByUserId: userId,
      reference: reason,
      note: 'تصحيح: الرصيد الافتتاحي الجديد',
      correctionGroup: correctionGroupId,
    );

    final index = _accounts.indexWhere((a) => a.id == id);
    _accounts[index] = FinancialAccount(
      id: account.id,
      name: account.name,
      type: account.type,
      isActive: account.isActive,
      allowNegativeBalance: account.allowNegativeBalance,
      openingBalanceQirsh: draft.correctedOpeningBalanceQirsh,
      openingBalanceDate: now,
      referenceInfo: account.referenceInfo,
      notes: account.notes,
      createdByUserId: account.createdByUserId,
      createdAt: account.createdAt,
    );

    _entries.add(originalEntry);
    _entries.add(correctedEntry);

    await _recordAudit(
      actionType: 'financial_account.opening_balance.corrected',
      descriptionAr:
          'تم تصحيح الرصيد الافتتاحي لحساب "${account.name}". السبب: $reason',
      referenceId: account.id,
    );
  }

  @override
  Future<bool> accountHasEntries(String accountId) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    return _entries.any((e) => e.accountId == id);
  }

  @override
  Future<FinancialAccountEntry> createEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amountQirsh,
    required FinancialAccountEntrySource sourceType,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    String? sourceDocumentNumber,
    String? reference,
    String? note,
    String? reversalOf,
    String? correctionGroup,
    PaymentMethod? paymentMethod,
    String? approvedByUserId,
    String? negativeBalanceApprovalId,
    String? approvalSourceDocumentId,
  }) {
    Future<FinancialAccountEntry> operation() => _createEntry(
          accountId: accountId,
          direction: direction,
          amountQirsh: amountQirsh,
          sourceType: sourceType,
          sourceDocumentId: sourceDocumentId,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId,
          sourceDocumentNumber: sourceDocumentNumber,
          reference: reference,
          note: note,
          reversalOf: reversalOf,
          correctionGroup: correctionGroup,
          paymentMethod: paymentMethod,
          approvedByUserId: approvedByUserId,
          negativeBalanceApprovalId: negativeBalanceApprovalId,
          approvalSourceDocumentId: approvalSourceDocumentId,
        );
    if (RepositoryTransaction.isActive) return operation();
    return RepositoryTransaction.execute(
      <SnapshotHolder>[createTransactionSnapshot()],
      operation,
    );
  }

  Future<FinancialAccountEntry> _createEntry({
    required String accountId,
    required FinancialAccountEntryDirection direction,
    required int amountQirsh,
    required FinancialAccountEntrySource sourceType,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    String? sourceDocumentNumber,
    String? reference,
    String? note,
    String? reversalOf,
    String? correctionGroup,
    PaymentMethod? paymentMethod,
    String? approvedByUserId,
    String? negativeBalanceApprovalId,
    String? approvalSourceDocumentId,
    bool authorizedSupplierOverpayment = false,
  }) async {
    final id = _normalizedRequiredId(accountId, 'accountId');
    final userId = _normalizedRequiredId(createdByUserId, 'createdByUserId');
    final account = await accountById(id);
    if (!account.isActive) throw StateError('Inactive financial account.');
    _ensureDateIsOpen(effectiveDate);

    if (amountQirsh <= 0) {
      throw ArgumentError.value(
        amountQirsh,
        'amountQirsh',
        'Entry amount must be positive.',
      );
    }

    bool negativeBalanceApproved = false;
    String? negativeApprovalId;
    if (direction == FinancialAccountEntryDirection.outflow) {
      final currentBalance = await currentBalanceForAccount(id);
      final projectedBalance = currentBalance - amountQirsh;
      if (projectedBalance < 0 && !authorizedSupplierOverpayment) {
        if (!account.allowNegativeBalance) {
          throw StateError(
            'الرصيد غير كافٍ. يجب تفعيل السماح بالرصيد السالب من قبل المالك.',
          );
        }
        final approver = negativeBalanceApprovalId?.trim();
        if (approver == null || approver.isEmpty) {
          throw StateError(
            'الرصيد غير كافٍ. تتطلب العملية موافقة المالك المباشرة.',
          );
        }
        negativeApprovalId = approver;
        negativeBalanceApproved = true;
      }
    }

    final now = DateTime.now();
    final entry = FinancialAccountEntry(
      id: _generateEntryId(now),
      accountId: id,
      direction: direction,
      amountQirsh: amountQirsh,
      sourceType: sourceType,
      sourceDocumentId: sourceDocumentId,
      sourceDocumentNumber: sourceDocumentNumber,
      effectiveDate: effectiveDate,
      createdAt: now,
      createdByUserId: userId,
      reference: reference,
      note: note,
      reversalOf: reversalOf,
      correctionGroup: correctionGroup,
      paymentMethod: paymentMethod,
      // Legacy data only. Authorization above is based exclusively on the
      // one-time approval id and never on a user id string.
      approvedByUserId: approvedByUserId?.trim().isEmpty == false
          ? approvedByUserId!.trim()
          : null,
      negativeBalanceApprovalId:
          negativeBalanceApproved ? negativeApprovalId : null,
    );
    NegativeBalanceApprovalConsumption? approvalConsumption;
    NegativeBalanceApprovalBinding? approvalBinding;
    if (negativeBalanceApproved) {
      final service = _negativeBalanceApprovalService;
      if (service == null) {
        throw StateError('خدمة اعتماد الرصيد السالب غير مهيأة.');
      }
      final balanceBefore = await currentBalanceForAccount(id);
      approvalBinding = NegativeBalanceApprovalBinding(
        approvalId: negativeApprovalId!,
        transactionId: entry.id,
        accountId: id,
        amountQirsh: amountQirsh,
        operationType: _operationTypeForSource(sourceType),
        sourceDocumentId: approvalSourceDocumentId?.trim().isEmpty == false
            ? approvalSourceDocumentId!.trim()
            : sourceDocumentId,
        sourceDocumentType: sourceType.name,
        requestedByUserId: userId,
        balanceBeforeQirsh: balanceBefore,
        expectedBalanceAfterQirsh: balanceBefore - amountQirsh,
      );
      await service.verify(approvalBinding);
    }
    try {
      _entries.add(entry);

      if (approvalBinding != null) {
        approvalConsumption = await _negativeBalanceApprovalService!.consume(
          approvalBinding,
        );
      }

      await _recordAudit(
        actionType: 'financial_account.entry.created',
        descriptionAr:
            'تم تسجيل حركة مالية ${direction.labelAr} بقيمة $amountQirsh قيرش.',
        referenceId: entry.id,
      );
      if (negativeBalanceApproved) {
        await _recordAudit(
          actionType: 'financial_account.entry.negative_balance_approved',
          descriptionAr: 'تمت موافقة المالك على حركة تجعل الرصيد سالبًا. '
              'الحساب: "${account.name}"، المبلغ: $amountQirsh قيرش.',
          referenceId: entry.id,
        );
      }
      return entry;
    } catch (_) {
      _entries.removeWhere((value) => value.id == entry.id);
      await approvalConsumption?.rollback();
      rethrow;
    }
  }

  @override
  Future<FinancialAccountEntry> createSupplierOverpaymentEntry({
    required String accountId,
    required int amountQirsh,
    required String sourceDocumentId,
    required DateTime effectiveDate,
    required String createdByUserId,
    required NegativeBalanceApprovalConsumption authorization,
    String? reference,
    String? note,
    PaymentMethod? paymentMethod,
  }) {
    authorization.claimSupplierOverpaymentEntry(
      accountId: accountId,
      amountQirsh: amountQirsh,
      createdByUserId: createdByUserId,
    );
    Future<FinancialAccountEntry> operation() => _createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: amountQirsh,
          sourceType: FinancialAccountEntrySource.supplierSettlement,
          sourceDocumentId: sourceDocumentId,
          effectiveDate: effectiveDate,
          createdByUserId: createdByUserId,
          reference: reference,
          note: note,
          paymentMethod: paymentMethod,
          authorizedSupplierOverpayment: true,
        );
    if (RepositoryTransaction.isActive) return operation();
    return RepositoryTransaction.execute(
      <SnapshotHolder>[createTransactionSnapshot()],
      operation,
    );
  }

  NegativeBalanceOperationType _operationTypeForSource(
    FinancialAccountEntrySource source,
  ) {
    switch (source) {
      case FinancialAccountEntrySource.expense:
        return NegativeBalanceOperationType.expense;
      case FinancialAccountEntrySource.supplierSettlement:
        return NegativeBalanceOperationType.supplierPayment;
      case FinancialAccountEntrySource.purchasePayment:
        return NegativeBalanceOperationType.purchasePayment;
      case FinancialAccountEntrySource.transferOut:
        return NegativeBalanceOperationType.transfer;
      case FinancialAccountEntrySource.cancellationReversal:
        return NegativeBalanceOperationType.cancellationReversal;
      case FinancialAccountEntrySource.supplierAdvanceRefundReversal:
        return NegativeBalanceOperationType.supplierOverpayment;
      case FinancialAccountEntrySource.customerAdvanceRefundReversal:
        return NegativeBalanceOperationType.customerOverpayment;
      default:
        throw StateError('مصدر الحركة لا يدعم اعماد الرصيد السالب.');
    }
  }

  @override
  Future<List<FinancialTransfer>> listTransfers() async =>
      List<FinancialTransfer>.unmodifiable(_transfers);

  @override
  Future<List<FinancialClosing>> listClosings() async =>
      List.unmodifiable(_closings.reversed);

  @override
  Future<FinancialClosing> createClosing(
      {required AppUser user, required FinancialClosingDraft draft}) async {
    _requireTransferOwner(user);
    final from = _dateOnly(draft.fromDate);
    final to = _dateOnly(draft.toDate);
    final today = _dateOnly(DateTime.now());
    if (to.isBefore(from) || to.isAfter(today)) {
      throw ArgumentError('Invalid or future closing period.');
    }
    if (draft.kind == FinancialClosingKind.daily &&
        !from.isAtSameMomentAs(to)) {
      throw ArgumentError('Daily closing must cover one day.');
    }
    if (_closings.any((c) =>
        !c.isOpen && !to.isBefore(c.fromDate) && !from.isAfter(c.toDate))) {
      throw StateError('The period overlaps an approved closing.');
    }
    final accounts = await listAccounts();
    if (accounts.isEmpty) throw StateError('No active financial accounts.');
    if (draft.actualBalancesQirsh.length != accounts.length ||
        accounts.any((a) => !draft.actualBalancesQirsh.containsKey(a.id))) {
      throw StateError('Actual balance is required for every active account.');
    }
    final lines = <FinancialClosingLine>[];
    for (final account in accounts) {
      var expected = 0;
      for (final entry in _entries.where((e) =>
          e.accountId == account.id &&
          !e.effectiveDate.isAfter(to
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1))))) {
        expected += entry.signedAmountQirsh;
      }
      lines.add(FinancialClosingLine(
          accountId: account.id,
          expectedBalanceQirsh: expected,
          actualBalanceQirsh: draft.actualBalancesQirsh[account.id]!));
    }
    final now = DateTime.now();
    final closing = FinancialClosing(
        id: 'fac-${now.microsecondsSinceEpoch}',
        kind: draft.kind,
        fromDate: from,
        toDate: to,
        lines: List.unmodifiable(lines),
        createdAt: now,
        createdByUserId: user.id,
        note: _normalizedOptionalText(draft.note));
    _closings.add(closing);
    await _recordAudit(
        actionType: 'financial_closing.approved',
        descriptionAr:
            'تم اعتماد الإغلاق المالي للفترة المحددة دون تعديل الأرصدة الدفترية.',
        referenceId: closing.id);
    return closing;
  }

  @override
  Future<FinancialClosing> reopenClosing(
      {required AppUser user,
      required String closingId,
      required String reason}) async {
    _requireTransferOwner(user);
    final cleanReason = _normalizedRequiredText(reason, 'reason');
    final index = _closings.indexWhere((c) => c.id == closingId);
    if (index < 0) throw StateError('Closing not found.');
    final old = _closings[index];
    if (old.isOpen) throw StateError('Closing already reopened.');
    final updated = FinancialClosing(
        id: old.id,
        kind: old.kind,
        fromDate: old.fromDate,
        toDate: old.toDate,
        lines: old.lines,
        createdAt: old.createdAt,
        createdByUserId: old.createdByUserId,
        note: old.note,
        reopenedAt: DateTime.now(),
        reopenedByUserId: user.id,
        reopenReason: cleanReason);
    _closings[index] = updated;
    await _recordAudit(
        actionType: 'financial_closing.reopened',
        descriptionAr: 'تمت إعادة فتح فترة مالية مع الاحتفاظ بسجل التسوية.',
        referenceId: old.id);
    return updated;
  }

  void _ensureDateIsOpen(DateTime value) {
    final date = _dateOnly(value);
    if (_closings.any((c) =>
        !c.isOpen && !date.isBefore(c.fromDate) && !date.isAfter(c.toDate))) {
      throw StateError('Cannot post into an approved closed period.');
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Future<FinancialTransfer> createTransfer({
    required AppUser user,
    required FinancialTransferDraft draft,
  }) {
    Future<FinancialTransfer> operation() =>
        _createTransfer(user: user, draft: draft);
    if (RepositoryTransaction.isActive) return operation();
    return RepositoryTransaction.execute(
      <SnapshotHolder>[createTransactionSnapshot()],
      operation,
    );
  }

  Future<FinancialTransfer> _createTransfer(
      {required AppUser user, required FinancialTransferDraft draft}) async {
    _requireTransferOwner(user);
    final sourceId =
        _normalizedRequiredId(draft.sourceAccountId, 'sourceAccountId');
    final destinationId = _normalizedRequiredId(
        draft.destinationAccountId, 'destinationAccountId');
    final requestId =
        _normalizedRequiredText(draft.clientRequestId, 'clientRequestId');
    final reference =
        _normalizedRequiredText(draft.transferReference, 'transferReference');
    final userId =
        _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (user.id != userId) {
      throw StateError('Transfer user does not match active session.');
    }
    if (sourceId == destinationId) {
      throw ArgumentError('لا يمكن التحويل إلى الحساب نفسه.');
    }
    if (draft.amountQirsh <= 0) {
      throw ArgumentError('مبلغ التحويل يجب أن يكون أكبر من صفر.');
    }
    if (draft.effectiveDate.isAfter(DateTime.now())) {
      throw ArgumentError('لا يسمح بتاريخ تحويل مستقبلي.');
    }
    _ensureDateIsOpen(draft.effectiveDate);
    final duplicate =
        _transfers.where((t) => t.clientRequestId == requestId).toList();
    if (duplicate.isNotEmpty) {
      final existing = duplicate.single;
      if (existing.sourceAccountId == sourceId &&
          existing.destinationAccountId == destinationId &&
          existing.amountQirsh == draft.amountQirsh &&
          existing.transferReference == reference) return existing;
      throw StateError('تم استخدام معرف الطلب مع بيانات تحويل مختلفة.');
    }
    if (_transfers.any((t) => t.transferReference == reference)) {
      throw StateError('مرجع التحويل مستخدم بالفعل.');
    }
    final source = await accountById(sourceId);
    final destination = await accountById(destinationId);
    if (!source.isActive || !destination.isActive) {
      throw StateError('الحساب المعطل لا يستخدم في تحويل جديد.');
    }
    bool transferNegativeBalanceOverride = false;
    int? sourceBalanceBefore;
    if (!source.allowNegativeBalance) {
      if (await currentBalanceForAccount(sourceId) < draft.amountQirsh) {
        throw StateError('رصيد الحساب المصدر غير كافٍ للتحويل.');
      }
    } else {
      final currentBalance = await currentBalanceForAccount(sourceId);
      if (currentBalance < draft.amountQirsh) {
        transferNegativeBalanceOverride = true;
        sourceBalanceBefore = currentBalance;
        if (draft.negativeBalanceApprovalId?.trim().isEmpty != false) {
          throw StateError('التحويل يتطلب معرف موافقة رصيد سالب صالح.');
        }
      }
    }
    final now = DateTime.now();
    final transferId = _generateTransferId(now);
    final sourceEntry = _newEntry(
        id: _generateEntryId(now),
        accountId: sourceId,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: draft.amountQirsh,
        sourceType: FinancialAccountEntrySource.transferOut,
        sourceDocumentId: transferId,
        sourceDocumentNumber: _displayNumber(),
        effectiveDate: draft.effectiveDate,
        createdAt: now,
        createdByUserId: userId,
        reference: reference,
        note: draft.note);
    final destinationEntry = _newEntry(
        id: _generateEntryId(now),
        accountId: destinationId,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: draft.amountQirsh,
        sourceType: FinancialAccountEntrySource.transferIn,
        sourceDocumentId: transferId,
        sourceDocumentNumber: sourceEntry.sourceDocumentNumber,
        effectiveDate: draft.effectiveDate,
        createdAt: now,
        createdByUserId: userId,
        reference: reference,
        note: draft.note);
    final transfer = FinancialTransfer(
        id: transferId,
        displayNumber: sourceEntry.sourceDocumentNumber!,
        clientRequestId: requestId,
        transferReference: reference,
        sourceAccountId: sourceId,
        destinationAccountId: destinationId,
        amountQirsh: draft.amountQirsh,
        effectiveDate: draft.effectiveDate,
        createdAt: now,
        createdByUserId: userId,
        sourceEntryId: sourceEntry.id,
        destinationEntryId: destinationEntry.id,
        note: _normalizedOptionalText(draft.note),
        negativeBalanceApprovalId: transferNegativeBalanceOverride
            ? draft.negativeBalanceApprovalId!.trim()
            : null);
    NegativeBalanceApprovalConsumption? approvalConsumption;
    NegativeBalanceApprovalBinding? approvalBinding;
    if (transferNegativeBalanceOverride) {
      final service = _negativeBalanceApprovalService;
      if (service == null) {
        throw StateError('خدمة اعتماد الرصيد السالب غير مهيأة.');
      }
      final balanceBefore = sourceBalanceBefore;
      if (balanceBefore == null) {
        throw StateError('تعذر تحديد رصيد الحساب المصدر.');
      }
      approvalBinding = NegativeBalanceApprovalBinding(
        approvalId: draft.negativeBalanceApprovalId!.trim(),
        transactionId: transfer.id,
        accountId: sourceId,
        amountQirsh: draft.amountQirsh,
        operationType: NegativeBalanceOperationType.transfer,
        sourceDocumentId: requestId,
        sourceDocumentType: 'transfer',
        requestedByUserId: userId,
        balanceBeforeQirsh: balanceBefore,
        expectedBalanceAfterQirsh: balanceBefore - draft.amountQirsh,
      );
      await service.verify(approvalBinding);
    }
    try {
      _transfers.add(transfer);
      _entries.addAll([sourceEntry, destinationEntry]);
      if (approvalBinding != null) {
        approvalConsumption = await _negativeBalanceApprovalService!.consume(
          approvalBinding,
        );
      }
      await _recordAudit(
          actionType: 'financial_transfer.created',
          descriptionAr: 'تم إنشاء تحويل مالي ${transfer.displayNumber}.',
          referenceId: transfer.id);
      if (transferNegativeBalanceOverride) {
        await _recordAudit(
            actionType: 'financial_transfer.negative_balance_override',
            descriptionAr:
                'تم تحويل مالي يجعل رصيد الحساب "${source.name}" سالبًا بموافقة المالك.',
            referenceId: transfer.id);
      }
      return transfer;
    } catch (_) {
      _transfers.removeWhere((value) => value.id == transfer.id);
      _entries.removeWhere(
        (value) =>
            value.id == sourceEntry.id || value.id == destinationEntry.id,
      );
      await approvalConsumption?.rollback();
      rethrow;
    }
  }

  @override
  Future<FinancialTransfer> reverseTransfer(
      {required AppUser user,
      required String transferId,
      required String reason}) async {
    _requireTransferOwner(user);
    final originalIndex = _transfers.indexWhere((t) => t.id == transferId);
    if (originalIndex < 0) throw StateError('التحويل غير موجود.');
    final original = _transfers[originalIndex];
    if (original.isReversal || original.isReversed) {
      throw StateError('لا يمكن عكس هذا التحويل.');
    }
    final cleanReason = _normalizedRequiredText(reason, 'reason');
    final userId = _normalizedRequiredId(user.id, 'createdByUserId');
    final now = DateTime.now();
    final reversalId = _generateTransferId(now);
    final number = _displayNumber();
    final out = _newEntry(
        id: _generateEntryId(now),
        accountId: original.destinationAccountId,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: original.amountQirsh,
        sourceType: FinancialAccountEntrySource.transferReversalOut,
        sourceDocumentId: reversalId,
        sourceDocumentNumber: number,
        effectiveDate: now,
        createdAt: now,
        createdByUserId: userId,
        reference: original.transferReference,
        note: cleanReason,
        reversalOf: original.destinationEntryId);
    final incoming = _newEntry(
        id: _generateEntryId(now),
        accountId: original.sourceAccountId,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: original.amountQirsh,
        sourceType: FinancialAccountEntrySource.transferReversalIn,
        sourceDocumentId: reversalId,
        sourceDocumentNumber: number,
        effectiveDate: now,
        createdAt: now,
        createdByUserId: userId,
        reference: original.transferReference,
        note: cleanReason,
        reversalOf: original.sourceEntryId);
    final reversal = FinancialTransfer(
        id: reversalId,
        displayNumber: number,
        clientRequestId: 'reversal-$reversalId',
        transferReference: '${original.transferReference}-R',
        sourceAccountId: original.destinationAccountId,
        destinationAccountId: original.sourceAccountId,
        amountQirsh: original.amountQirsh,
        effectiveDate: now,
        createdAt: now,
        createdByUserId: userId,
        sourceEntryId: out.id,
        destinationEntryId: incoming.id,
        note: cleanReason,
        originalTransferId: original.id,
        reversalReason: cleanReason);
    _transfers[originalIndex] = FinancialTransfer(
        id: original.id,
        displayNumber: original.displayNumber,
        clientRequestId: original.clientRequestId,
        transferReference: original.transferReference,
        sourceAccountId: original.sourceAccountId,
        destinationAccountId: original.destinationAccountId,
        amountQirsh: original.amountQirsh,
        effectiveDate: original.effectiveDate,
        createdAt: original.createdAt,
        createdByUserId: original.createdByUserId,
        sourceEntryId: original.sourceEntryId,
        destinationEntryId: original.destinationEntryId,
        note: original.note,
        reversalTransferId: reversal.id);
    _transfers.add(reversal);
    _entries.addAll([out, incoming]);
    await _recordAudit(
        actionType: 'financial_transfer.reversed',
        descriptionAr: 'تم عكس التحويل المالي ${original.displayNumber}.',
        referenceId: reversal.id);
    return reversal;
  }

  FinancialAccountEntry _newEntry(
          {required String id,
          required String accountId,
          required FinancialAccountEntryDirection direction,
          required int amountQirsh,
          required FinancialAccountEntrySource sourceType,
          required String sourceDocumentId,
          required String? sourceDocumentNumber,
          required DateTime effectiveDate,
          required DateTime createdAt,
          required String createdByUserId,
          String? reference,
          String? note,
          String? reversalOf}) =>
      FinancialAccountEntry(
          id: id,
          accountId: accountId,
          direction: direction,
          amountQirsh: amountQirsh,
          sourceType: sourceType,
          sourceDocumentId: sourceDocumentId,
          sourceDocumentNumber: sourceDocumentNumber,
          effectiveDate: effectiveDate,
          createdAt: createdAt,
          createdByUserId: createdByUserId,
          reference: reference,
          note: note,
          reversalOf: reversalOf);

  void _requireTransferOwner(AppUser user) {
    if (!user.canProceed || user.role != UserRole.owner) {
      throw StateError('Financial transfers are available to the owner only.');
    }
  }

  Future<void> restoreFinancialAccountsIntoEmpty({
    required List<FinancialAccount> accounts,
    required List<FinancialAccountEntry> entries,
    List<FinancialTransfer> transfers = const [],
    List<FinancialClosing> closings = const [],
  }) async {
    if (_accounts.isNotEmpty || _entries.isNotEmpty) {
      throw StateError('Financial account repository is not empty.');
    }
    _validateUniqueRestoredAccounts(accounts);
    _validateUniqueRestoredEntries(entries);
    _validateRestoredTransfers(accounts, entries, transfers);
    _validateRestoredClosings(accounts, closings);
    _accounts.addAll(accounts);
    _entries.addAll(entries);
    _transfers.addAll(transfers);
    _closings.addAll(closings);
  }

  Future<void> clearForOwnerDataWipe() async {
    _accounts.clear();
    _entries.clear();
    _transfers.clear();
    _closings.clear();
    _generatedAccountIdCounter = 0;
    _generatedEntryIdCounter = 0;
    _generatedTransferIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    final ownState = ObjectStateSnapshot<
        (
          List<FinancialAccount>,
          List<FinancialAccountEntry>,
          List<FinancialTransfer>,
          List<FinancialClosing>,
          int,
          int,
          int
        )>(
      captureState: () => (
        List<FinancialAccount>.from(_accounts),
        List<FinancialAccountEntry>.from(_entries),
        List<FinancialTransfer>.from(_transfers),
        List<FinancialClosing>.from(_closings),
        _generatedAccountIdCounter,
        _generatedEntryIdCounter,
        _generatedTransferIdCounter,
      ),
      restoreState: (state) {
        _accounts
          ..clear()
          ..addAll(state.$1);
        _entries
          ..clear()
          ..addAll(state.$2);
        _transfers
          ..clear()
          ..addAll(state.$3);
        _closings
          ..clear()
          ..addAll(state.$4);
        _generatedAccountIdCounter = state.$5;
        _generatedEntryIdCounter = state.$6;
        _generatedTransferIdCounter = state.$7;
      },
    );
    final snapshots = <SnapshotHolder>[ownState];
    if (_auditLogRepository is TransactionSnapshotProvider) {
      snapshots.add(
        (_auditLogRepository as TransactionSnapshotProvider)
            .createTransactionSnapshot(),
      );
    } else {
      throw StateError('مستودع التدقيق لا يدعم المعاملات الذرية.');
    }
    final approvalService = _negativeBalanceApprovalService;
    if (approvalService != null) {
      snapshots.add(approvalService.createTransactionSnapshot());
    }
    return CompositeSnapshot(snapshots);
  }

  void _validateDraft(FinancialAccountDraft draft) {
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        draft.name,
        'name',
        'اسم الحساب مطلوب.',
      );
    }
  }

  void _validateUniqueRestoredAccounts(List<FinancialAccount> accounts) {
    final ids = <String>{};
    final names = <String>{};
    for (final account in accounts) {
      if (!account.hasValidId) {
        throw StateError('Invalid financial account id.');
      }
      if (!ids.add(account.id)) {
        throw StateError('Duplicate financial account id.');
      }
      if (account.isActive && !names.add(account.name)) {
        throw StateError('Duplicate active financial account name.');
      }
    }
  }

  void _validateUniqueRestoredEntries(List<FinancialAccountEntry> entries) {
    final ids = <String>{};
    for (final entry in entries) {
      if (!entry.hasValidId) {
        throw StateError('Invalid financial account entry id.');
      }
      if (!ids.add(entry.id)) {
        throw StateError('Duplicate financial account entry id.');
      }
    }
  }

  void _validateRestoredTransfers(List<FinancialAccount> accounts,
      List<FinancialAccountEntry> entries, List<FinancialTransfer> transfers) {
    final accountIds = accounts.map((value) => value.id).toSet();
    final entryIds = entries.map((value) => value.id).toSet();
    final transferIds = <String>{};
    final requestIds = <String>{};
    final references = <String>{};
    for (final transfer in transfers) {
      if (!transferIds.add(transfer.id) ||
          !requestIds.add(transfer.clientRequestId) ||
          !references.add(transfer.transferReference) ||
          transfer.sourceAccountId == transfer.destinationAccountId ||
          transfer.amountQirsh <= 0 ||
          !accountIds.contains(transfer.sourceAccountId) ||
          !accountIds.contains(transfer.destinationAccountId) ||
          !entryIds.contains(transfer.sourceEntryId) ||
          !entryIds.contains(transfer.destinationEntryId)) {
        throw StateError('Invalid financial transfer backup data.');
      }
    }
  }

  void _validateRestoredClosings(
      List<FinancialAccount> accounts, List<FinancialClosing> closings) {
    final accountIds = accounts.map((value) => value.id).toSet();
    final closingIds = <String>{};
    for (final closing in closings) {
      final lineAccountIds = <String>{};
      if (closing.id.trim().isEmpty ||
          !closingIds.add(closing.id) ||
          closing.toDate.isBefore(closing.fromDate) ||
          closing.lines.isEmpty ||
          closing.lines.any((line) =>
              !accountIds.contains(line.accountId) ||
              !lineAccountIds.add(line.accountId))) {
        throw StateError('Invalid financial closing backup data.');
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

  String _normalizedRequiredText(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
    return normalized;
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String _generateAccountId(DateTime now) {
    _generatedAccountIdCounter++;
    return 'fa-${now.microsecondsSinceEpoch}-$_generatedAccountIdCounter';
  }

  String _generateEntryId(DateTime now) {
    _generatedEntryIdCounter++;
    return 'fae-${now.microsecondsSinceEpoch}-$_generatedEntryIdCounter';
  }

  String _generateTransferId(DateTime now) =>
      'fat-${now.microsecondsSinceEpoch}-${++_generatedTransferIdCounter}';
  String _displayNumber() =>
      'TR-${(_generatedTransferIdCounter).toString().padLeft(6, '0')}';

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
