import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
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
  Future<CustomerAccountEntry> createCashSaleEntry({
    required SaleRecord sale,
    required String customerId,
  });
  Future<CustomerCollectionRecord> createCollection(
    CustomerCollectionDraft draft,
  );
  Future<List<CustomerAdvance>> listAdvances();
  Future<List<CustomerAdvanceApplication>> listAdvanceApplications();
  Future<List<CustomerAdvanceRefund>> listAdvanceRefunds();
  Future<int> remainingAdvanceQirsh(String advanceId);
  Future<CustomerAdvanceApplication> applyAdvance(
    CustomerAdvanceApplicationDraft draft,
  );
  Future<CustomerAdvanceRefund> refundAdvance(CustomerAdvanceRefundDraft draft);
  Future<CustomerAdvanceApplication> reverseAdvanceApplication(
      {required AppUser user,
      required String applicationId,
      required String reason,
      required String operationRequestId});
  Future<CustomerAdvanceRefund> reverseAdvanceRefund(
      {required AppUser user,
      required String refundId,
      required String reason,
      required String operationRequestId,
      String? overpaymentApprovalId});
  Future<CustomerCollectionCancellation> cancelCollection({
    required AppUser user,
    required String collectionId,
    required String reason,
    required String operationRequestId,
  });

  Future<CustomerAccountEntry> createOpeningBalanceEntry({
    required String customerId,
    required int amountQirsh,
    required String createdByUserId,
  });

  Future<bool> hasOpeningBalanceEntry(String customerId);

  Future<CustomerAccountEntry> reverseSaleEntry({
    required SaleRecord cancelledSale,
    required String cancelledByUserId,
    required String cancellationReason,
  });
}

abstract class DurableCustomerAccountRepository
    implements CustomerAccountRepository, TransactionSnapshotProvider {
  Future<void> restoreCustomerAccountsIntoEmpty({
    required List<CustomerAccountEntry> entries,
    required List<CustomerCollectionRecord> collections,
    List<CustomerAdvance> advances = const [],
    List<CustomerAdvanceApplication> applications = const [],
    List<CustomerAdvanceRefund> refunds = const [],
  });

  Future<void> clearForOwnerDataWipe();
}

class LocalCustomerAccountRepository
    implements DurableCustomerAccountRepository {
  LocalCustomerAccountRepository({
    required CustomerRepository customerRepository,
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
    NegativeBalanceApprovalService? negativeBalanceApprovalService,
  })  : _customerRepository = customerRepository,
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository,
        _negativeBalanceApprovalService = negativeBalanceApprovalService;

  final CustomerRepository _customerRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final NegativeBalanceApprovalService? _negativeBalanceApprovalService;
  final List<CustomerAccountEntry> _entries = [];
  final List<CustomerCollectionRecord> _collections = [];
  final List<CustomerAdvance> _advances = [];
  final List<CustomerAdvanceApplication> _advanceApplications = [];
  final List<CustomerAdvanceRefund> _advanceRefunds = [];
  final Map<String, String> _advanceRequestFingerprints = {};
  final Map<String, String> _cancellationRequestIds = {};
  int _generatedEntryIdCounter = 0;
  int _generatedCollectionIdCounter = 0;
  int _generatedCancellationIdCounter = 0;
  int _generatedAdvanceIdCounter = 0;
  int _generatedAdvanceApplicationIdCounter = 0;
  int _generatedAdvanceRefundIdCounter = 0;

  @override
  Future<List<CustomerAccountEntry>> listEntries() async {
    final sorted = [..._entries]..sort((a, b) {
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
        entry.sourceDocumentType == 'sale' &&
        entry.sourceDocumentId == sale.id)) {
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
      descriptionAr:
          '\u0628\u064a\u0639 \u0622\u062c\u0644 \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}',
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
  Future<CustomerAccountEntry> createCashSaleEntry({
    required SaleRecord sale,
    required String customerId,
  }) async {
    final customer = await _requireCustomer(customerId, includeInactive: false);
    if (sale.paymentMode != SalePaymentMode.cash &&
        sale.paymentMode != SalePaymentMode.partial) {
      throw StateError('Only cash and partial sales create cash entries.');
    }
    if (sale.customerId != customer.id) {
      throw StateError('Sale customer does not match ledger customer.');
    }
    if (sale.totalQirsh <= 0 || sale.isCancelled) {
      throw StateError('Invalid sale for customer ledger.');
    }
    if (_entries.any((entry) =>
        entry.sourceDocumentType == 'sale' &&
        entry.sourceDocumentId == sale.id)) {
      throw StateError('Sale ledger entry already exists.');
    }

    final now = DateTime.now();
    final paidAmount = sale.effectivePaidAmountQirsh;
    final descriptionAr = sale.isPartialPayment
        ? '\u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 - \u062f\u0641\u0639 \u062c\u0632\u0626\u064a \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}'
        : '\u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 \u0646\u0642\u062f\u064a \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}';

    final entry = CustomerAccountEntry(
      id: _generateEntryId(now),
      customerId: customer.id,
      date: sale.createdAt,
      type: CustomerAccountEntryType.cashSale,
      debitAmountQirsh: sale.totalQirsh,
      creditAmountQirsh: paidAmount,
      sourceDocumentType: 'sale',
      sourceDocumentId: sale.id,
      descriptionAr: descriptionAr,
      createdAt: now,
      createdByUserId: sale.createdByUserId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'customer.cash_sale.posted',
      descriptionAr:
          '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0641\u0627\u062a\u0648\u0631\u0629 \u0628\u064a\u0639 \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}.',
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
    await _validateNewPaymentRoute(
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
    );
    final balance = await balanceForCustomer(customer.id);
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
            'Customer overpayment requires account, request id, and owner approval.');
      }
      if (_negativeBalanceApprovalService == null) {
        throw StateError(
            'Customer advance approval service is not configured.');
      }
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
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
      settledAmountQirsh: settledAmountQirsh,
      advanceAmountQirsh: advanceAmountQirsh,
    );
    _validateCollection(collection);

    final entry = settledAmountQirsh == 0
        ? null
        : CustomerAccountEntry(
            id: _generateEntryId(now),
            customerId: customer.id,
            date: collection.date,
            type: CustomerAccountEntryType.collection,
            debitAmountQirsh: 0,
            creditAmountQirsh: settledAmountQirsh,
            sourceDocumentType: 'customerCollection',
            sourceDocumentId: collection.id,
            descriptionAr: 'Collection from ${customer.name}',
            createdAt: now,
            createdByUserId: collection.createdByUserId,
          );
    if (entry != null) _validateEntry(entry);
    final advance = advanceAmountQirsh == 0
        ? null
        : CustomerAdvance(
            id: _generateAdvanceId(now),
            customerId: customer.id,
            sourceCollectionId: collection.id,
            financialAccountId: collection.financialAccountId!.trim(),
            amountQirsh: advanceAmountQirsh,
            createdAt: now,
            createdByUserId: collection.createdByUserId,
            ownerApprovalId: draft.overpaymentApprovalId!.trim(),
            operationRequestId: draft.operationRequestId!.trim(),
            paymentMethod: collection.paymentMethod,
          );

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    final financialRepository = _financialAccountRepository;
    if (financialRepository is TransactionSnapshotProvider) {
      snapshots.add(
        (financialRepository as TransactionSnapshotProvider)
            .createTransactionSnapshot(),
      );
    } else if (collection.financialAccountId?.trim().isNotEmpty == true) {
      throw StateError('Financial account repository is not transaction-safe.');
    }
    final approvalService = _negativeBalanceApprovalService;
    if (advance != null) {
      snapshots.add(approvalService!.createTransactionSnapshot());
    }
    return RepositoryTransaction.execute(snapshots, () async {
      NegativeBalanceApprovalBinding? advanceApprovalBinding;
      final requestId = _normalizedOptionalText(draft.operationRequestId);
      final fingerprint = _collectionFingerprint(draft);
      if (requestId != null &&
          _advanceRequestFingerprints.containsKey(requestId)) {
        throw StateError('Customer collection request was already processed.');
      }
      final lockedBalance = await balanceForCustomer(customer.id);
      final lockedSettled = lockedBalance <= 0
          ? 0
          : draft.amountQirsh < lockedBalance
              ? draft.amountQirsh
              : lockedBalance;
      if (lockedSettled != settledAmountQirsh) {
        throw StateError('Customer balance changed; retry the collection.');
      }
      if (advance != null) {
        final activeApprovalService = approvalService!;
        final accountBalance = await financialRepository!
            .currentBalanceForAccount(advance.financialAccountId);
        advanceApprovalBinding = NegativeBalanceApprovalBinding(
          approvalId: advance.ownerApprovalId,
          transactionId: collection.id,
          accountId: advance.financialAccountId,
          amountQirsh: advance.amountQirsh,
          operationType: NegativeBalanceOperationType.customerOverpayment,
          sourceDocumentId: requestId!,
          sourceDocumentType: 'customerOverpayment',
          requestedByUserId: collection.createdByUserId,
          balanceBeforeQirsh: accountBalance,
          expectedBalanceAfterQirsh: accountBalance + collection.amountQirsh,
        );
        await activeApprovalService.verify(advanceApprovalBinding);
      }
      _collections.add(collection);
      if (entry != null) _entries.add(entry);
      if (advance != null) _advances.add(advance);
      if (financialRepository != null &&
          collection.financialAccountId?.trim().isNotEmpty == true) {
        await financialRepository.createEntry(
          accountId: collection.financialAccountId!,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: collection.amountQirsh,
          sourceType: FinancialAccountEntrySource.customerCollection,
          sourceDocumentId: collection.id,
          effectiveDate: collection.date,
          createdByUserId: collection.createdByUserId,
          reference: 'Customer collection ${customer.name}',
          note: 'Collection ${collection.amountQirsh} qirsh',
          paymentMethod: collection.paymentMethod,
        );
      }
      if (advance != null) {
        await approvalService!.consume(advanceApprovalBinding!);
      }
      if (requestId != null) {
        _advanceRequestFingerprints[requestId] = fingerprint;
      }
      await _recordAudit(
        actionType: advance == null
            ? 'customer.collection.recorded'
            : 'customer.advance.created',
        descriptionAr: 'Customer collection recorded.',
        referenceId: advance?.id ?? collection.id,
      );
      return collection;
    });
  }

  @override
  Future<List<CustomerAdvance>> listAdvances() async =>
      List<CustomerAdvance>.unmodifiable(_advances);

  @override
  Future<List<CustomerAdvanceApplication>> listAdvanceApplications() async =>
      List<CustomerAdvanceApplication>.unmodifiable(_advanceApplications);

  @override
  Future<List<CustomerAdvanceRefund>> listAdvanceRefunds() async =>
      List<CustomerAdvanceRefund>.unmodifiable(_advanceRefunds);

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
  Future<CustomerAdvanceApplication> applyAdvance(
    CustomerAdvanceApplicationDraft draft,
  ) async {
    final advance =
        _advanceById(_normalizedRequiredId(draft.advanceId, 'advanceId'));
    final customerId = _normalizedRequiredId(draft.customerId, 'customerId');
    final requestId =
        _normalizedRequiredId(draft.operationRequestId, 'operationRequestId');
    _normalizedRequiredId(draft.createdByUserId, 'createdByUserId');
    if (draft.amountQirsh <= 0) {
      throw ArgumentError.value(draft.amountQirsh, 'amountQirsh');
    }
    if (advance.customerId != customerId || advance.isReversed) {
      throw StateError('Advance does not belong to the active customer.');
    }
    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    return RepositoryTransaction.execute(snapshots, () async {
      final fingerprint =
          'apply|${draft.advanceId}|$customerId|${draft.amountQirsh}|${draft.date.toUtc().toIso8601String()}';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceApplications
            .firstWhere((value) => value.operationRequestId == requestId);
      }
      final receivable = await balanceForCustomer(customerId);
      final remaining = await remainingAdvanceQirsh(advance.id);
      if (receivable < draft.amountQirsh || remaining < draft.amountQirsh) {
        throw StateError(
            'Advance application exceeds its available amount or customer receivable.');
      }
      final now = DateTime.now();
      final entry = CustomerAccountEntry(
        id: _generateEntryId(now),
        customerId: customerId,
        date: draft.date,
        type: CustomerAccountEntryType.advanceApplication,
        debitAmountQirsh: 0,
        creditAmountQirsh: draft.amountQirsh,
        sourceDocumentType: 'customerAdvanceApplication',
        sourceDocumentId: requestId,
        descriptionAr: 'تطبيق سلفة العميل',
        createdAt: now,
        createdByUserId: draft.createdByUserId.trim(),
      );
      _validateEntry(entry);
      final application = CustomerAdvanceApplication(
        id: _generateAdvanceApplicationId(now),
        advanceId: advance.id,
        customerId: customerId,
        amountQirsh: draft.amountQirsh,
        appliedAt: now,
        createdByUserId: draft.createdByUserId.trim(),
        operationRequestId: requestId,
        customerLedgerEntryId: entry.id,
      );
      _entries.add(entry);
      _advanceApplications.add(application);
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'customer.advance.applied',
          descriptionAr: 'Customer advance applied.',
          referenceId: application.id);
      return application;
    });
  }

  @override
  Future<CustomerAdvanceRefund> refundAdvance(
      CustomerAdvanceRefundDraft draft) async {
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
      throw StateError('Refund must use the original financial account.');
    }
    final financialRepository = _financialAccountRepository ??
        (throw StateError(
            'Financial account repository is required and must be transaction-safe.'));
    if (financialRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Financial account repository is required and must be transaction-safe.');
    }
    final paymentMethod = draft.paymentMethod ?? advance.paymentMethod;
    if (paymentMethod == null) {
      throw StateError('طريقة الدفع مطلوبة لرد سلفة العميل.');
    }
    final account = await financialRepository.accountById(accountId);
    PaymentRoutingPolicy.validateAccount(
      account: account,
      paymentMethod: paymentMethod,
    );
    final financialSnapshotProvider =
        financialRepository as TransactionSnapshotProvider;
    return RepositoryTransaction.execute(<SnapshotHolder>[
      createTransactionSnapshot(),
      financialSnapshotProvider.createTransactionSnapshot(),
    ], () async {
      final fingerprint =
          'refund|${draft.advanceId}|${draft.amountQirsh}|$accountId|${paymentMethod.name}|${draft.date.toUtc().toIso8601String()}';
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
        throw StateError('Refund exceeds available customer advance.');
      }
      final now = DateTime.now();
      final refundId = _generateAdvanceRefundId(now);
      final balanceBefore =
          await financialRepository.currentBalanceForAccount(accountId);
      final requiresApproval = balanceBefore - draft.amountQirsh < 0;
      NegativeBalanceApprovalConsumption? authorization;
      if (requiresApproval) {
        final approvalId = _normalizedOptionalText(
          draft.negativeBalanceApprovalId,
        );
        if (approvalId == null) {
          throw StateError(
              'رد سلفة العميل يتطلب موافقة المالك على الرصيد السالب.');
        }
        final approvalService = _negativeBalanceApprovalService;
        if (approvalService == null) {
          throw StateError('خدمة موافقات الرصيد السالب غير مهيأة.');
        }
        authorization = await approvalService.consume(
          NegativeBalanceApprovalBinding(
            approvalId: approvalId,
            transactionId: refundId,
            accountId: accountId,
            amountQirsh: draft.amountQirsh,
            operationType: NegativeBalanceOperationType.customerAdvanceRefund,
            sourceDocumentId: requestId,
            sourceDocumentType: 'customerAdvanceRefund',
            requestedByUserId: draft.createdByUserId.trim(),
            balanceBeforeQirsh: balanceBefore,
            expectedBalanceAfterQirsh: balanceBefore - draft.amountQirsh,
            authorizationContext:
                NegativeBalanceApprovalContext.customerAdvanceRefund(
              customerId: advance.customerId,
              advanceId: advance.id,
            ),
          ),
        );
      }
      final financialEntry = authorization == null
          ? await financialRepository.createEntry(
              accountId: accountId,
              direction: FinancialAccountEntryDirection.outflow,
              amountQirsh: draft.amountQirsh,
              sourceType: FinancialAccountEntrySource.customerAdvanceRefund,
              sourceDocumentId: requestId,
              effectiveDate: draft.date,
              createdByUserId: draft.createdByUserId.trim(),
              paymentMethod: paymentMethod,
              reference: 'رد سلفة العميل',
            )
          : await financialRepository.createCustomerAdvanceRefundEntry(
              accountId: accountId,
              customerId: advance.customerId,
              advanceId: advance.id,
              amountQirsh: draft.amountQirsh,
              sourceDocumentId: requestId,
              effectiveDate: draft.date,
              createdByUserId: draft.createdByUserId.trim(),
              paymentMethod: paymentMethod,
              reference: 'رد سلفة العميل',
              authorization: authorization,
            );
      final refund = CustomerAdvanceRefund(
        id: refundId,
        advanceId: advance.id,
        customerId: advance.customerId,
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
        actionType: 'customer.advance.refunded',
        descriptionAr: 'تم رد سلفة العميل.',
        referenceId: refund.id,
      );
      return refund;
    });
  }

  @override
  Future<CustomerAdvanceApplication> reverseAdvanceApplication(
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
        throw StateError('Customer advance application was not found.');
      }
      final application = _advanceApplications[applicationIndex];
      final fingerprint = 'customer|reverse-application|$id|$cleanReason';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceApplications[applicationIndex];
      }
      final advance = _advanceById(application.advanceId);
      if (advance.isReversed) {
        throw StateError('Customer advance source is reversed.');
      }
      if (application.isReversed) {
        throw StateError('Customer advance application was already reversed.');
      }
      final now = DateTime.now();
      final entry = CustomerAccountEntry(
        id: _generateEntryId(now),
        customerId: application.customerId,
        date: now,
        type: CustomerAccountEntryType.advanceApplicationReversal,
        debitAmountQirsh: application.amountQirsh,
        creditAmountQirsh: 0,
        sourceDocumentType: 'customerAdvanceApplicationReversal',
        sourceDocumentId: application.id,
        descriptionAr: 'عكس تطبيق سلفة العميل: $cleanReason',
        createdAt: now,
        createdByUserId: user.id,
      );
      _validateEntry(entry);
      _entries.add(entry);
      _advanceApplications[applicationIndex] = CustomerAdvanceApplication(
        id: application.id,
        advanceId: application.advanceId,
        customerId: application.customerId,
        amountQirsh: application.amountQirsh,
        appliedAt: application.appliedAt,
        createdByUserId: application.createdByUserId,
        operationRequestId: application.operationRequestId,
        customerLedgerEntryId: application.customerLedgerEntryId,
        reversedAt: now,
        reversedByUserId: user.id,
        reversalReason: cleanReason,
        reversalLedgerEntryId: entry.id,
      );
      _advanceRequestFingerprints[requestId] = fingerprint;
      await _recordAudit(
          actionType: 'customer.advance.application.reversed',
          descriptionAr: 'تم عكس تطبيق سلفة العميل.',
          referenceId: application.id);
      return _advanceApplications[applicationIndex];
    });
  }

  @override
  Future<CustomerAdvanceRefund> reverseAdvanceRefund(
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
    final financialSnapshotProvider =
        financialRepository as TransactionSnapshotProvider;
    return RepositoryTransaction.execute(<SnapshotHolder>[
      createTransactionSnapshot(),
      financialSnapshotProvider.createTransactionSnapshot()
    ], () async {
      final refundIndex = _advanceRefunds.indexWhere((value) => value.id == id);
      if (refundIndex < 0) {
        throw StateError('Customer advance refund was not found.');
      }
      final refund = _advanceRefunds[refundIndex];
      final fingerprint = 'customer|reverse-refund|$id|$cleanReason';
      final replay = _advanceRequestFingerprints[requestId];
      if (replay != null) {
        if (replay != fingerprint) {
          throw StateError('Request id payload mismatch.');
        }
        return _advanceRefunds[refundIndex];
      }
      if (refund.isReversed) {
        throw StateError('Customer advance refund was already reversed.');
      }
      final advance = _advanceById(refund.advanceId);
      if (advance.isReversed) {
        throw StateError('Customer advance source is reversed.');
      }
      final originalFinancialEntry = await financialRepository
          .statementForAccount(refund.financialAccountId);
      FinancialAccountEntry? originalEntry;
      for (final line in originalFinancialEntry.lines) {
        if (line.entry.sourceDocumentId == refund.operationRequestId &&
            line.entry.sourceType ==
                FinancialAccountEntrySource.customerAdvanceRefund) {
          originalEntry = line.entry;
          break;
        }
      }
      if (originalEntry == null) {
        throw StateError('Financial entry for this refund was not found.');
      }
      final now = DateTime.now();
      final reversalEntry = await financialRepository.createEntry(
        accountId: refund.financialAccountId,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: refund.amountQirsh,
        sourceType: FinancialAccountEntrySource.customerAdvanceRefundReversal,
        sourceDocumentId: refund.id,
        effectiveDate: now,
        createdByUserId: user.id,
        reversalOf: originalEntry.id,
        reference: 'عكس رد سلفة العميل',
        note: cleanReason,
        negativeBalanceApprovalId: overpaymentApprovalId,
        approvalSourceDocumentId: requestId,
      );
      _advanceRefunds[refundIndex] = CustomerAdvanceRefund(
        id: refund.id,
        advanceId: refund.advanceId,
        customerId: refund.customerId,
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
          actionType: 'customer.advance.refund.reversed',
          descriptionAr: 'تم عكس رد سلفة العميل.',
          referenceId: refund.id);
      return _advanceRefunds[refundIndex];
    });
  }

  @override
  Future<CustomerCollectionCancellation> cancelCollection({
    required AppUser user,
    required String collectionId,
    required String reason,
    required String operationRequestId,
  }) async {
    _requireOwner(user);
    final id = _normalizedRequiredId(collectionId, 'collectionId');
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
            'Collection cancellation request was already processed.');
      }
      final index =
          _collections.indexWhere((collection) => collection.id == id);
      if (index < 0) throw StateError('Customer collection was not found.');
      final collection = _collections[index];
      if (collection.isCancelled) {
        throw StateError('Customer collection was already cancelled.');
      }
      final sourceAdvanceIndex = _advances.indexWhere(
        (advance) => advance.sourceCollectionId == collection.id,
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
              'Customer advance source cannot be reversed while active applications or refunds exist.');
        }
        _advances[sourceAdvanceIndex] = CustomerAdvance(
          id: advance.id,
          customerId: advance.customerId,
          sourceCollectionId: advance.sourceCollectionId,
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
      final customer = await _requireCustomer(
        collection.customerId,
        includeInactive: true,
      );
      final now = DateTime.now();
      final cancellationId = _generateCancellationId(now);
      final ledgerReversal = CustomerAccountEntry(
        id: _generateEntryId(now),
        customerId: collection.customerId,
        date: now,
        type: CustomerAccountEntryType.collectionCancellation,
        debitAmountQirsh:
            collection.settledAmountQirsh ?? collection.amountQirsh,
        creditAmountQirsh: 0,
        sourceDocumentType: 'customerCollectionCancellation',
        sourceDocumentId: cancellationId,
        descriptionAr: 'عكس تحصيل العميل ${customer.name}: $cleanReason',
        createdAt: now,
        createdByUserId: user.id,
      );
      _validateEntry(ledgerReversal);
      _entries.add(ledgerReversal);

      String? financialReversalEntryId;
      if (collection.financialAccountId?.trim().isNotEmpty == true) {
        final statement = await financialRepository!.statementForAccount(
          collection.financialAccountId!,
        );
        FinancialAccountEntry? originalFinancialEntry;
        for (final line in statement.lines) {
          if (line.entry.sourceType ==
                  FinancialAccountEntrySource.customerCollection &&
              line.entry.sourceDocumentId == collection.id) {
            originalFinancialEntry = line.entry;
            break;
          }
        }
        if (originalFinancialEntry == null) {
          throw StateError(
              'Financial entry for this collection was not found.');
        }
        final financialReversal = await financialRepository.createEntry(
          accountId: collection.financialAccountId!,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: collection.amountQirsh,
          sourceType: FinancialAccountEntrySource.cancellationReversal,
          sourceDocumentId: cancellationId,
          effectiveDate: now,
          createdByUserId: user.id,
          reference: 'عكس التحصيل ${collection.id}',
          note: cleanReason,
          reversalOf: originalFinancialEntry.id,
          paymentMethod: collection.paymentMethod,
        );
        financialReversalEntryId = financialReversal.id;
      }

      final cancellation = CustomerCollectionCancellation(
        id: cancellationId,
        originalCollectionId: collection.id,
        cancelledAt: now,
        cancelledByUserId: user.id,
        reason: cleanReason,
        customerLedgerReversalEntryId: ledgerReversal.id,
        financialAccountReversalEntryId: financialReversalEntryId,
      );
      _collections[index] = CustomerCollectionRecord(
        id: collection.id,
        customerId: collection.customerId,
        date: collection.date,
        amountQirsh: collection.amountQirsh,
        createdAt: collection.createdAt,
        createdByUserId: collection.createdByUserId,
        createdByUserName: collection.createdByUserName,
        notes: collection.notes,
        financialAccountId: collection.financialAccountId,
        paymentMethod: collection.paymentMethod,
        cancellation: cancellation,
      );
      _cancellationRequestIds[requestId] = cancellationId;
      await _recordAudit(
        actionType: 'customer.collection.reversed',
        descriptionAr: 'تم عكس تحصيل العميل ${customer.name}.',
        referenceId: cancellationId,
      );
      return cancellation;
    });
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
      descriptionAr:
          '\u0631\u0635\u064a\u062f \u0627\u0641\u062a\u062a\u0627\u062d\u064a \u0644\u0644\u0639\u0645\u064a\u0644',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(entry);
    _entries.add(entry);
    await _recordAudit(
      actionType: 'customer.opening-balance.posted',
      descriptionAr:
          '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0631\u0635\u064a\u062f \u0627\u0641\u062a\u062a\u0627\u062d\u064a \u0644\u0644\u0639\u0645\u064a\u0644.',
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

  @override
  Future<CustomerAccountEntry> reverseSaleEntry({
    required SaleRecord cancelledSale,
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
          entry.sourceDocumentType == 'sale' &&
          entry.sourceDocumentId == cancelledSale.id,
    );
    if (originalEntryIndex < 0) {
      throw StateError('No ledger entry found for this sale.');
    }

    final originalEntry = _entries[originalEntryIndex];
    final customer = await _requireCustomer(
      originalEntry.customerId,
      includeInactive: true,
    );

    final netImpact = originalEntry.signedBalanceImpactQirsh;
    if (netImpact <= 0) {
      return originalEntry;
    }

    final balanceBeforeReversal = await balanceForCustomer(customer.id);
    final collectedAmount = netImpact - balanceBeforeReversal;
    if (collectedAmount > 0) {
      throw StateError(
        'Cannot cancel sale: customer has made collections against this sale.',
      );
    }

    final now = DateTime.now();
    final reversalEntry = CustomerAccountEntry(
      id: _generateEntryId(now),
      customerId: originalEntry.customerId,
      date: now,
      type: CustomerAccountEntryType.saleCancellation,
      debitAmountQirsh: 0,
      creditAmountQirsh: netImpact,
      sourceDocumentType: 'saleCancellation',
      sourceDocumentId: cancelledSale.id,
      descriptionAr:
          '\u0625\u0644\u063a\u0627\u0621 \u0628\u064a\u0639 \u0644\u0644\u0639\u0645\u064a\u0644 ${customer.name}: $reason',
      createdAt: now,
      createdByUserId: userId,
    );
    _validateEntry(reversalEntry);
    _entries.add(reversalEntry);
    await _recordAudit(
      actionType: 'customer.sale.reversed',
      descriptionAr:
          '\u062a\u0645 \u0639\u0643\u0633 \u0642\u064a\u062f \u0628\u064a\u0639 \u0627\u0644\u0639\u0645\u064a\u0644 ${customer.name}.',
      referenceId: cancelledSale.id,
    );
    return reversalEntry;
  }

  @override
  Future<void> restoreCustomerAccountsIntoEmpty({
    required List<CustomerAccountEntry> entries,
    required List<CustomerCollectionRecord> collections,
    List<CustomerAdvance> advances = const [],
    List<CustomerAdvanceApplication> applications = const [],
    List<CustomerAdvanceRefund> refunds = const [],
  }) async {
    if (_entries.isNotEmpty ||
        _collections.isNotEmpty ||
        _advances.isNotEmpty ||
        _advanceApplications.isNotEmpty ||
        _advanceRefunds.isNotEmpty) {
      throw StateError('Customer account repository is not empty.');
    }
    _validateUniqueRestoredEntries(entries);
    _validateUniqueRestoredCollections(collections);
    _entries.addAll(entries);
    _collections.addAll(collections);
    _validateRestoredAdvances(advances, applications, refunds);
    _advances.addAll(advances);
    _advanceApplications.addAll(applications);
    _advanceRefunds.addAll(refunds);
    _generatedEntryIdCounter = _maxIdCounter(entries.map((v) => v.id));
    _generatedCollectionIdCounter = _maxIdCounter(collections.map((v) => v.id));
    _generatedCancellationIdCounter = _maxIdCounter(
        collections.map((v) => v.cancellation?.id).whereType<String>());
    _generatedAdvanceIdCounter = _maxIdCounter(advances.map((v) => v.id));
    _generatedAdvanceApplicationIdCounter =
        _maxIdCounter(applications.map((v) => v.id));
    _generatedAdvanceRefundIdCounter = _maxIdCounter(refunds.map((v) => v.id));
    for (final value in [
      ...advances.map((v) => v.operationRequestId),
      ...applications.map((v) => v.operationRequestId),
      ...refunds.map((v) => v.operationRequestId)
    ]) {
      _advanceRequestFingerprints[value] = 'restored:$value';
    }
  }

  int _maxIdCounter(Iterable<String> ids) {
    var maximum = 0;
    for (final id in ids) {
      final value = int.tryParse(id.split('-').last);
      if (value != null && value > maximum) maximum = value;
    }
    return maximum;
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _entries.clear();
    _collections.clear();
    _advances.clear();
    _advanceApplications.clear();
    _advanceRefunds.clear();
    _cancellationRequestIds.clear();
    _advanceRequestFingerprints.clear();
    _generatedEntryIdCounter = 0;
    _generatedCollectionIdCounter = 0;
    _generatedCancellationIdCounter = 0;
    _generatedAdvanceIdCounter = 0;
    _generatedAdvanceApplicationIdCounter = 0;
    _generatedAdvanceRefundIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    final auditRepository = _auditLogRepository;
    if (auditRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Audit repository does not support atomic transactions.');
    }
    return CompositeSnapshot([
      ObjectStateSnapshot<_CustomerAccountState>(
        captureState: () => _CustomerAccountState(
          entries: List<CustomerAccountEntry>.from(_entries),
          collections: List<CustomerCollectionRecord>.from(_collections),
          advances: List<CustomerAdvance>.from(_advances),
          applications:
              List<CustomerAdvanceApplication>.from(_advanceApplications),
          refunds: List<CustomerAdvanceRefund>.from(_advanceRefunds),
          cancellationRequestIds:
              Map<String, String>.from(_cancellationRequestIds),
          advanceRequestFingerprints:
              Map<String, String>.from(_advanceRequestFingerprints),
          entryCounter: _generatedEntryIdCounter,
          collectionCounter: _generatedCollectionIdCounter,
          cancellationCounter: _generatedCancellationIdCounter,
          advanceCounter: _generatedAdvanceIdCounter,
          applicationCounter: _generatedAdvanceApplicationIdCounter,
          refundCounter: _generatedAdvanceRefundIdCounter,
        ),
        restoreState: (state) {
          _entries
            ..clear()
            ..addAll(state.entries);
          _collections
            ..clear()
            ..addAll(state.collections);
          _advances
            ..clear()
            ..addAll(state.advances);
          _advanceApplications
            ..clear()
            ..addAll(state.applications);
          _advanceRefunds
            ..clear()
            ..addAll(state.refunds);
          _cancellationRequestIds
            ..clear()
            ..addAll(state.cancellationRequestIds);
          _advanceRequestFingerprints
            ..clear()
            ..addAll(state.advanceRequestFingerprints);
          _generatedEntryIdCounter = state.entryCounter;
          _generatedCollectionIdCounter = state.collectionCounter;
          _generatedCancellationIdCounter = state.cancellationCounter;
          _generatedAdvanceIdCounter = state.advanceCounter;
          _generatedAdvanceApplicationIdCounter = state.applicationCounter;
          _generatedAdvanceRefundIdCounter = state.refundCounter;
        },
      ),
      (auditRepository as TransactionSnapshotProvider)
          .createTransactionSnapshot(),
    ]);
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

  Future<void> _validateNewPaymentRoute({
    required String? financialAccountId,
    required PaymentMethod? paymentMethod,
  }) async {
    final repository = _financialAccountRepository;
    // Legacy ledger-only adapters deliberately have no financial repository.
    // The production graph always supplies one and therefore enforces the
    // complete route before any collection state is mutated.
    if (repository == null) return;
    final accountId = _normalizedOptionalText(financialAccountId);
    if (accountId == null) {
      throw StateError('الحساب المالي مطلوب لتسجيل التحصيل.');
    }
    if (paymentMethod == null) {
      throw StateError('طريقة الدفع مطلوبة لتسجيل التحصيل.');
    }
    final account = await repository.accountById(accountId);
    PaymentRoutingPolicy.validateAccount(
      account: account,
      paymentMethod: paymentMethod,
    );
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
    if (entry.debitAmountQirsh == 0 && entry.creditAmountQirsh == 0) {
      throw StateError(
          'Customer ledger entry must have a debit or credit amount.');
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
          'Customer collection cancellation is available to the owner only.');
    }
  }

  String _generateEntryId(DateTime now) {
    _generatedEntryIdCounter++;
    return 'cle-${now.microsecondsSinceEpoch}-$_generatedEntryIdCounter';
  }

  String _generateCollectionId(DateTime now) {
    _generatedCollectionIdCounter++;
    return 'col-${now.microsecondsSinceEpoch}-$_generatedCollectionIdCounter';
  }

  String _generateCancellationId(DateTime now) {
    _generatedCancellationIdCounter++;
    return 'ccr-${now.microsecondsSinceEpoch}-$_generatedCancellationIdCounter';
  }

  void _validateRestoredAdvances(
    List<CustomerAdvance> advances,
    List<CustomerAdvanceApplication> applications,
    List<CustomerAdvanceRefund> refunds,
  ) {
    final ids = <String>{};
    for (final value in advances) {
      if (!value.hasValidId || value.amountQirsh <= 0 || !ids.add(value.id)) {
        throw StateError('Invalid or duplicate customer advance.');
      }
    }
    final sourceIds = advances.map((value) => value.id).toSet();
    for (final value in applications) {
      if (!value.hasValidId ||
          value.amountQirsh <= 0 ||
          !sourceIds.contains(value.advanceId)) {
        throw StateError('Orphan or invalid customer advance operation.');
      }
    }
    for (final value in refunds) {
      if (!value.hasValidId ||
          value.amountQirsh <= 0 ||
          !sourceIds.contains(value.advanceId)) {
        throw StateError('Orphan or invalid customer advance operation.');
      }
    }
  }

  String _generateAdvanceId(DateTime now) {
    _generatedAdvanceIdCounter++;
    return 'cad-${now.microsecondsSinceEpoch}-$_generatedAdvanceIdCounter';
  }

  String _generateAdvanceApplicationId(DateTime now) {
    _generatedAdvanceApplicationIdCounter++;
    return 'caa-${now.microsecondsSinceEpoch}-$_generatedAdvanceApplicationIdCounter';
  }

  String _generateAdvanceRefundId(DateTime now) {
    _generatedAdvanceRefundIdCounter++;
    return 'car-${now.microsecondsSinceEpoch}-$_generatedAdvanceRefundIdCounter';
  }

  CustomerAdvance _advanceById(String id) {
    for (final advance in _advances) {
      if (advance.id == id) return advance;
    }
    throw StateError('Customer advance was not found.');
  }

  String _collectionFingerprint(CustomerCollectionDraft draft) => [
        'collection',
        draft.customerId.trim(),
        draft.date.toUtc().toIso8601String(),
        draft.amountQirsh,
        draft.createdByUserId.trim(),
        draft.financialAccountId?.trim() ?? '',
        draft.paymentMethod?.name ?? '',
        draft.overpaymentApprovalId?.trim() ?? '',
      ].join('|');

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

class _CustomerAccountState {
  const _CustomerAccountState({
    required this.entries,
    required this.collections,
    required this.advances,
    required this.applications,
    required this.refunds,
    required this.cancellationRequestIds,
    required this.advanceRequestFingerprints,
    required this.entryCounter,
    required this.collectionCounter,
    required this.cancellationCounter,
    required this.advanceCounter,
    required this.applicationCounter,
    required this.refundCounter,
  });
  final List<CustomerAccountEntry> entries;
  final List<CustomerCollectionRecord> collections;
  final List<CustomerAdvance> advances;
  final List<CustomerAdvanceApplication> applications;
  final List<CustomerAdvanceRefund> refunds;
  final Map<String, String> cancellationRequestIds;
  final Map<String, String> advanceRequestFingerprints;
  final int entryCounter;
  final int collectionCounter;
  final int cancellationCounter;
  final int advanceCounter;
  final int applicationCounter;
  final int refundCounter;
}
