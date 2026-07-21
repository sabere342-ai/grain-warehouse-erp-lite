import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';

void main() {
  group('Phase 4A customer advance refund approval contract', () {
    test('dedicated operation is stable and has an Arabic label', () {
      expect(NegativeBalanceOperationType.customerAdvanceRefund.name,
          'customerAdvanceRefund');
      expect(
        NegativeBalanceOperationType.customerAdvanceRefund.labelAr,
        'رد سلفة عميل',
      );
    });

    test('funded refund succeeds without consuming an approval', () async {
      final fixture = await _Fixture.create(drainAccount: false);

      final refund = await fixture.refund(requestId: 'funded-refund');

      expect(refund.amountQirsh, 100);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          1200);
      expect(fixture.approvals.consumeCalls, 0);
      expect(
          await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 100);
    });

    test('negative refund without approval is rejected atomically', () async {
      final fixture = await _Fixture.create();
      final state = await fixture.captureState();

      await expectLater(
        fixture.refund(requestId: 'missing-approval'),
        throwsStateError,
      );

      await fixture.expectState(state);
    });

    test('exact approval verifies and consumes once', () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'exact-refund');

      final refund = await fixture.refund(
        requestId: 'exact-refund',
        approvalId: approvalId,
      );

      expect(refund.amountQirsh, 100);
      expect(fixture.approvals.verifyCalls, 1);
      expect(fixture.approvals.consumeCalls, 1);
      final approval = await fixture.approvalRepository.findById(approvalId);
      expect(approval!.status, NegativeBalanceApprovalStatus.consumed);
      final statement =
          await fixture.accounts.statementForAccount(fixture.account.id);
      final entry = statement.lines.last.entry;
      expect(
          entry.sourceType, FinancialAccountEntrySource.customerAdvanceRefund);
      expect(entry.negativeBalanceApprovalId, approvalId);
      expect(
          await fixture.accounts.currentBalanceForAccount(fixture.account.id),
          -100);
    });

    test('customer, advance, account, amount, request and requester are bound',
        () async {
      final cases = <String, Future<String> Function(_Fixture)>{
        'customer': (f) => f.approve(
              requestId: 'bound-customer',
              customerId: 'another-customer',
            ),
        'advance': (f) => f.approve(
              requestId: 'bound-advance',
              advanceId: 'another-advance',
            ),
        'account': (f) => f.approve(
              requestId: 'bound-account',
              accountId: 'another-account',
            ),
        'amount': (f) => f.approve(
              requestId: 'bound-amount',
              amountQirsh: 101,
              balanceBeforeQirsh: 0,
            ),
        'request': (f) => f.approve(requestId: 'another-request'),
        'requester': (f) => f.approve(
              requestId: 'bound-requester',
              requestedByUserId: 'another-user',
            ),
      };

      for (final entry in cases.entries) {
        final fixture = await _Fixture.create();
        final requestId = 'bound-${entry.key}';
        final approvalId = await entry.value(fixture);
        await expectLater(
          fixture.refund(requestId: requestId, approvalId: approvalId),
          throwsStateError,
          reason: entry.key,
        );
        expect(
          (await fixture.approvalRepository.findById(approvalId))!.status,
          NegativeBalanceApprovalStatus.pending,
          reason: entry.key,
        );
      }
    });

    test('operation, source type, and direction are exact', () async {
      final fixture = await _Fixture.create();
      await expectLater(
        fixture
            .approve(
              requestId: 'wrong-operation',
              operationType: NegativeBalanceOperationType.expense,
            )
            .then((id) => fixture.refund(
                  requestId: 'wrong-operation',
                  approvalId: id,
                )),
        throwsStateError,
      );
      await expectLater(
        fixture
            .approve(
              requestId: 'wrong-source',
              sourceDocumentType: 'customerCollection',
            )
            .then((id) => fixture.refund(
                  requestId: 'wrong-source',
                  approvalId: id,
                )),
        throwsStateError,
      );
      await expectLater(
        fixture.approve(
          requestId: 'wrong-direction',
          context: NegativeBalanceApprovalContext(
            customerId: fixture.customer.id,
            advanceId: fixture.advance.id,
            financialDirection: NegativeBalanceFinancialDirection.inflow,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('ordinary financial caller cannot use customer refund approval',
        () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'direct-entry');

      await expectLater(
        fixture.accounts.createEntry(
          accountId: fixture.account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 100,
          sourceType: FinancialAccountEntrySource.customerAdvanceRefund,
          sourceDocumentId: 'direct-entry',
          effectiveDate: DateTime(2026, 7, 15),
          createdByUserId: fixture.ownerId,
          negativeBalanceApprovalId: approvalId,
          approvalSourceDocumentId: 'direct-entry',
        ),
        throwsArgumentError,
      );
      expect(
        (await fixture.approvalRepository.findById(approvalId))!.status,
        NegativeBalanceApprovalStatus.pending,
      );
    });

    test('supplier receipt cannot authorize customer refund entry', () async {
      final fixture = await _Fixture.create();
      const requestId = 'supplier-receipt';
      final approvalId = await fixture.approvals.requestApproval(
        draft: NegativeBalanceApprovalDraft(
          requestedByUserId: fixture.ownerId,
          approvedByOwnerUserId: fixture.ownerId,
          accountId: fixture.account.id,
          amountQirsh: 100,
          operationType: NegativeBalanceOperationType.supplierOverpayment,
          sourceDocumentId: requestId,
          sourceDocumentType: 'supplierOverpayment',
          balanceBeforeQirsh: 0,
          expectedBalanceAfterQirsh: -100,
          reason: 'Supplier receipt isolation',
        ),
        ownerPhone: _Fixture.ownerPhone,
        ownerPassword: _Fixture.ownerPassword,
      );
      final receipt = await fixture.approvals.consume(
        NegativeBalanceApprovalBinding(
          approvalId: approvalId,
          transactionId: 'supplier-txn',
          accountId: fixture.account.id,
          amountQirsh: 100,
          operationType: NegativeBalanceOperationType.supplierOverpayment,
          sourceDocumentId: requestId,
          sourceDocumentType: 'supplierOverpayment',
          requestedByUserId: fixture.ownerId,
          balanceBeforeQirsh: 0,
          expectedBalanceAfterQirsh: -100,
        ),
      );

      expect(
        () => fixture.accounts.createCustomerAdvanceRefundEntry(
          accountId: fixture.account.id,
          customerId: fixture.customer.id,
          advanceId: fixture.advance.id,
          amountQirsh: 100,
          sourceDocumentId: requestId,
          effectiveDate: DateTime(2026, 7, 15),
          createdByUserId: fixture.ownerId,
          authorization: receipt,
        ),
        throwsStateError,
      );
    });

    test('customer refund receipt cannot authorize supplier settlement',
        () async {
      final fixture = await _Fixture.create();
      const requestId = 'customer-receipt';
      final approvalId = await fixture.approve(requestId: requestId);
      final receipt = await fixture.approvals.consume(
        fixture.binding(approvalId: approvalId, requestId: requestId),
      );

      expect(
        () => fixture.accounts.createSupplierOverpaymentEntry(
          accountId: fixture.account.id,
          amountQirsh: 100,
          sourceDocumentId: requestId,
          effectiveDate: DateTime(2026, 7, 15),
          createdByUserId: fixture.ownerId,
          authorization: receipt,
        ),
        throwsStateError,
      );
    });

    test('customer refund receipt and consumed approval are single-use',
        () async {
      final fixture = await _Fixture.create();
      const requestId = 'single-use-receipt';
      final approvalId = await fixture.approve(requestId: requestId);
      final receipt = await fixture.approvals.consume(
        fixture.binding(approvalId: approvalId, requestId: requestId),
      );
      await fixture.accounts.createCustomerAdvanceRefundEntry(
        accountId: fixture.account.id,
        customerId: fixture.customer.id,
        advanceId: fixture.advance.id,
        amountQirsh: 100,
        sourceDocumentId: requestId,
        effectiveDate: DateTime(2026, 7, 15),
        createdByUserId: fixture.ownerId,
        authorization: receipt,
      );
      expect(
        () => fixture.accounts.createCustomerAdvanceRefundEntry(
          accountId: fixture.account.id,
          customerId: fixture.customer.id,
          advanceId: fixture.advance.id,
          amountQirsh: 100,
          sourceDocumentId: requestId,
          effectiveDate: DateTime(2026, 7, 15),
          createdByUserId: fixture.ownerId,
          authorization: receipt,
        ),
        throwsStateError,
      );

      final orchestrated = await _Fixture.create();
      final usedApproval =
          await orchestrated.approve(requestId: 'used-approval');
      await orchestrated.refund(
        requestId: 'used-approval',
        approvalId: usedApproval,
      );
      await expectLater(
        orchestrated.refund(
          requestId: 'reuse-approval',
          approvalId: usedApproval,
          amountQirsh: 50,
        ),
        throwsStateError,
      );
      expect((await orchestrated.ledger.listAdvanceRefunds()).length, 1);
    });

    test('successful replay and concurrent duplicate create one refund',
        () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'replay-refund');
      final first = await fixture.refund(
        requestId: 'replay-refund',
        approvalId: approvalId,
      );
      final replay = await fixture.refund(
        requestId: 'replay-refund',
        approvalId: approvalId,
      );
      expect(replay.id, first.id);
      expect((await fixture.ledger.listAdvanceRefunds()).length, 1);

      final concurrent = await _Fixture.create();
      final concurrentApproval =
          await concurrent.approve(requestId: 'concurrent-refund');
      final results = await Future.wait([
        concurrent.refund(
          requestId: 'concurrent-refund',
          approvalId: concurrentApproval,
        ),
        concurrent.refund(
          requestId: 'concurrent-refund',
          approvalId: concurrentApproval,
        ),
      ]);
      expect(results[0].id, results[1].id);
      expect((await concurrent.ledger.listAdvanceRefunds()).length, 1);
      expect(concurrent.approvals.consumeCalls, 1);
    });

    test('same request with changed content is rejected', () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'mismatch-refund');
      await fixture.refund(
        requestId: 'mismatch-refund',
        approvalId: approvalId,
      );

      await expectLater(
        fixture.refund(
          requestId: 'mismatch-refund',
          approvalId: approvalId,
          amountQirsh: 99,
        ),
        throwsStateError,
      );
      expect((await fixture.ledger.listAdvanceRefunds()).length, 1);
    });

    test('audit failure restores approval, refund, entry, replay and counters',
        () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'rollback-refund');
      final state = await fixture.captureState();
      fixture.audit.failCustomerRefund = true;

      await expectLater(
        fixture.refund(
          requestId: 'rollback-refund',
          approvalId: approvalId,
        ),
        throwsStateError,
      );

      await fixture.expectState(state);
      expect(
        (await fixture.approvalRepository.findById(approvalId))!.status,
        NegativeBalanceApprovalStatus.pending,
      );
      fixture.audit.failCustomerRefund = false;
      final retry = await fixture.refund(
        requestId: 'rollback-refund',
        approvalId: approvalId,
      );
      expect(retry.id, endsWith('-1'));
    });

    test('partial, full, exhausted and reversed availability is enforced',
        () async {
      final partial = await _Fixture.create(drainAccount: false);
      await partial.refund(requestId: 'partial', amountQirsh: 75);
      expect(
          await partial.ledger.remainingAdvanceQirsh(partial.advance.id), 125);

      final full = await _Fixture.create(drainAccount: false);
      await full.refund(requestId: 'full', amountQirsh: 200);
      expect(await full.ledger.remainingAdvanceQirsh(full.advance.id), 0);
      await expectLater(
        full.refund(requestId: 'exhausted', amountQirsh: 1),
        throwsStateError,
      );
      await expectLater(
        full.refund(requestId: 'above', amountQirsh: 201),
        throwsStateError,
      );

      final reversed = await _Fixture.create(drainAccount: false);
      await reversed.ledger.cancelCollection(
        user: reversed.owner,
        collectionId: reversed.advance.sourceCollectionId,
        reason: 'Reverse source collection',
        operationRequestId: 'reverse-source-collection',
      );
      expect(
          await reversed.ledger.remainingAdvanceQirsh(reversed.advance.id), 0);
      await expectLater(
        reversed.refund(requestId: 'reversed-advance'),
        throwsStateError,
      );
    });

    test('approval repository round trip preserves typed binding context',
        () async {
      final fixture = await _Fixture.create();
      final approvalId = await fixture.approve(requestId: 'restore-approval');
      final restoredRepository = LocalNegativeBalanceApprovalRepository();
      await restoredRepository
          .restoreIntoEmpty(await fixture.approvalRepository.listAll());

      final restored = await restoredRepository.findById(approvalId);
      expect(restored!.operationType,
          NegativeBalanceOperationType.customerAdvanceRefund);
      expect(restored.authorizationContext!.customerId, fixture.customer.id);
      expect(restored.authorizationContext!.advanceId, fixture.advance.id);
      expect(restored.authorizationContext!.financialDirection,
          NegativeBalanceFinancialDirection.outflow);
    });
  });
}

class _FixtureState {
  const _FixtureState({
    required this.balance,
    required this.remaining,
    required this.refundCount,
    required this.financialEntryCount,
    required this.auditCount,
  });

  final int balance;
  final int remaining;
  final int refundCount;
  final int financialEntryCount;
  final int auditCount;
}

class _Fixture {
  _Fixture._({
    required this.ownerId,
    required this.owner,
    required this.audit,
    required this.approvalRepository,
    required this.approvals,
    required this.accounts,
    required this.account,
    required this.customer,
    required this.ledger,
    required this.advance,
  });

  static const ownerPhone = '01000000400';
  static const ownerPassword = 'phase4a-test-only';

  final String ownerId;
  final AppUser owner;
  final _ToggleAudit audit;
  final LocalNegativeBalanceApprovalRepository approvalRepository;
  final _CountingApprovalService approvals;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;
  final Customer customer;
  final LocalCustomerAccountRepository ledger;
  final CustomerAdvance advance;

  static Future<_Fixture> create({bool drainAccount = true}) async {
    final audit = _ToggleAudit();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(
      name: 'Phase 4A Owner',
      phone: ownerPhone,
      password: ownerPassword,
    );
    final approvalRepository = LocalNegativeBalanceApprovalRepository();
    final approvals = _CountingApprovalService(
      authRepository: auth,
      approvalRepository: approvalRepository,
      auditLogRepository: audit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit,
      negativeBalanceApprovalService: approvals,
    );
    final account = await accounts.createAccount(FinancialAccountDraft(
      name: 'Phase 4A Cash',
      type: FinancialAccountType.treasury,
      allowNegativeBalance: true,
      createdByUserId: owner.id,
    ));
    await accounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 100,
      effectiveDate: DateTime(2026, 7, 1),
      createdByUserId: owner.id,
    );
    final customerRepository = LocalCustomerRepository(
      auditLogRepository: audit,
    );
    final customer = await customerRepository.createCustomer(
      const CustomerDraft(name: 'Phase 4A Customer'),
    );
    final ledger = LocalCustomerAccountRepository(
      customerRepository: customerRepository,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
      negativeBalanceApprovalService: approvals,
    );
    await ledger.createOpeningBalanceEntry(
      customerId: customer.id,
      amountQirsh: 1000,
      createdByUserId: owner.id,
    );
    const overpaymentRequest = 'phase4a-overpayment';
    final overpaymentApproval = await approvals.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: owner.id,
        approvedByOwnerUserId: owner.id,
        accountId: account.id,
        amountQirsh: 200,
        operationType: NegativeBalanceOperationType.customerOverpayment,
        sourceDocumentId: overpaymentRequest,
        sourceDocumentType: 'customerOverpayment',
        balanceBeforeQirsh: 100,
        expectedBalanceAfterQirsh: 1300,
        reason: 'Create customer advance',
      ),
      ownerPhone: ownerPhone,
      ownerPassword: ownerPassword,
    );
    await ledger.createCollection(CustomerCollectionDraft(
      customerId: customer.id,
      date: DateTime(2026, 7, 10),
      amountQirsh: 1200,
      createdByUserId: owner.id,
      financialAccountId: account.id,
      paymentMethod: PaymentMethod.cash,
      operationRequestId: overpaymentRequest,
      overpaymentApprovalId: overpaymentApproval,
    ));
    final advance = (await ledger.listAdvances()).single;
    if (drainAccount) {
      await accounts.createEntry(
        accountId: account.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 1300,
        sourceType: FinancialAccountEntrySource.manualCorrection,
        sourceDocumentId: 'phase4a-drain',
        effectiveDate: DateTime(2026, 7, 11),
        createdByUserId: owner.id,
      );
    }
    approvals.resetCounts();
    return _Fixture._(
      ownerId: owner.id,
      owner: owner,
      audit: audit,
      approvalRepository: approvalRepository,
      approvals: approvals,
      accounts: accounts,
      account: account,
      customer: customer,
      ledger: ledger,
      advance: advance,
    );
  }

  Future<String> approve({
    required String requestId,
    String? customerId,
    String? advanceId,
    String? accountId,
    String? requestedByUserId,
    int amountQirsh = 100,
    int balanceBeforeQirsh = 0,
    NegativeBalanceOperationType operationType =
        NegativeBalanceOperationType.customerAdvanceRefund,
    String sourceDocumentType = 'customerAdvanceRefund',
    NegativeBalanceApprovalContext? context,
  }) {
    return approvals.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: requestedByUserId ?? ownerId,
        approvedByOwnerUserId: ownerId,
        accountId: accountId ?? account.id,
        amountQirsh: amountQirsh,
        operationType: operationType,
        sourceDocumentId: requestId,
        sourceDocumentType: sourceDocumentType,
        balanceBeforeQirsh: balanceBeforeQirsh,
        expectedBalanceAfterQirsh: balanceBeforeQirsh - amountQirsh,
        reason: 'Authorize customer advance refund',
        authorizationContext: context ??
            NegativeBalanceApprovalContext.customerAdvanceRefund(
              customerId: customerId ?? customer.id,
              advanceId: advanceId ?? advance.id,
            ),
      ),
      ownerPhone: ownerPhone,
      ownerPassword: ownerPassword,
    );
  }

  NegativeBalanceApprovalBinding binding({
    required String approvalId,
    required String requestId,
  }) {
    return NegativeBalanceApprovalBinding(
      approvalId: approvalId,
      transactionId: 'manual-refund-transaction',
      accountId: account.id,
      amountQirsh: 100,
      operationType: NegativeBalanceOperationType.customerAdvanceRefund,
      sourceDocumentId: requestId,
      sourceDocumentType: 'customerAdvanceRefund',
      requestedByUserId: ownerId,
      balanceBeforeQirsh: 0,
      expectedBalanceAfterQirsh: -100,
      authorizationContext:
          NegativeBalanceApprovalContext.customerAdvanceRefund(
        customerId: customer.id,
        advanceId: advance.id,
      ),
    );
  }

  Future<CustomerAdvanceRefund> refund({
    required String requestId,
    String? approvalId,
    int amountQirsh = 100,
  }) {
    return ledger.refundAdvance(CustomerAdvanceRefundDraft(
      advanceId: advance.id,
      amountQirsh: amountQirsh,
      date: DateTime(2026, 7, 15),
      createdByUserId: ownerId,
      operationRequestId: requestId,
      financialAccountId: account.id,
      paymentMethod: PaymentMethod.cash,
      negativeBalanceApprovalId: approvalId,
    ));
  }

  Future<_FixtureState> captureState() async {
    return _FixtureState(
      balance: await accounts.currentBalanceForAccount(account.id),
      remaining: await ledger.remainingAdvanceQirsh(advance.id),
      refundCount: (await ledger.listAdvanceRefunds()).length,
      financialEntryCount:
          (await accounts.statementForAccount(account.id)).lines.length,
      auditCount: (await audit.listLogs()).length,
    );
  }

  Future<void> expectState(_FixtureState state) async {
    expect(await accounts.currentBalanceForAccount(account.id), state.balance);
    expect(await ledger.remainingAdvanceQirsh(advance.id), state.remaining);
    expect((await ledger.listAdvanceRefunds()).length, state.refundCount);
    expect((await accounts.statementForAccount(account.id)).lines.length,
        state.financialEntryCount);
    expect((await audit.listLogs()).length, state.auditCount);
  }
}

class _CountingApprovalService extends NegativeBalanceApprovalService {
  _CountingApprovalService({
    required super.authRepository,
    required super.approvalRepository,
    required super.auditLogRepository,
  });

  int verifyCalls = 0;
  int consumeCalls = 0;

  void resetCounts() {
    verifyCalls = 0;
    consumeCalls = 0;
  }

  @override
  Future<void> verify(NegativeBalanceApprovalBinding binding) {
    verifyCalls++;
    return super.verify(binding);
  }

  @override
  Future<NegativeBalanceApprovalConsumption> consume(
      NegativeBalanceApprovalBinding binding) {
    consumeCalls++;
    return super.consume(binding);
  }
}

class _ToggleAudit extends LocalAuditLogRepository {
  bool failCustomerRefund = false;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (failCustomerRefund && draft.actionType == 'customer.advance.refunded') {
      throw StateError('Injected customer refund audit failure.');
    }
    return super.record(draft);
  }
}
