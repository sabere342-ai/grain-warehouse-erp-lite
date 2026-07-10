import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

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
  Future<void> setOpeningBalance({
    required String accountId,
    required int amountQirsh,
    required DateTime effectiveDate,
    required String createdByUserId,
  });
  Future<void> correctOpeningBalance(OpeningBalanceCorrectionDraft draft);
  Future<bool> accountHasEntries(String accountId);
}

class LocalFinancialAccountRepository implements FinancialAccountRepository {
  LocalFinancialAccountRepository({AuditLogRepository? auditLogRepository})
      : _auditLogRepository = auditLogRepository;

  final AuditLogRepository? _auditLogRepository;
  final List<FinancialAccount> _accounts = [];
  final List<FinancialAccountEntry> _entries = [];
  int _generatedAccountIdCounter = 0;
  int _generatedEntryIdCounter = 0;

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

    var accountEntries = _entries
        .where((e) => e.accountId == id)
        .toList(growable: false);
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
  Future<void> correctOpeningBalance(OpeningBalanceCorrectionDraft draft) async {
    final id = _normalizedRequiredId(draft.accountId, 'accountId');
    final userId = _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
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

  Future<void> restoreFinancialAccountsIntoEmpty({
    required List<FinancialAccount> accounts,
    required List<FinancialAccountEntry> entries,
  }) async {
    if (_accounts.isNotEmpty || _entries.isNotEmpty) {
      throw StateError('Financial account repository is not empty.');
    }
    _validateUniqueRestoredAccounts(accounts);
    _validateUniqueRestoredEntries(entries);
    _accounts.addAll(accounts);
    _entries.addAll(entries);
  }

  Future<void> clearForOwnerDataWipe() async {
    _accounts.clear();
    _entries.clear();
    _generatedAccountIdCounter = 0;
    _generatedEntryIdCounter = 0;
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
