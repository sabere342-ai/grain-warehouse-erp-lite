import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';

void main() {
  test('customer overpayment keeps receivable and advance separate', () async {
    final fixture = await _CustomerAdvanceFixture.create();
    const requestId = 'customer-overpay-1';
    final approvalId = await fixture.approve(
      requestId: requestId,
      amountQirsh: 200,
      expectedBalanceAfterQirsh: 2200,
    );
    final collection = await fixture.ledger.createCollection(
      CustomerCollectionDraft(
        customerId: fixture.customerId,
        date: DateTime(2026, 7, 13),
        amountQirsh: 1200,
        createdByUserId: fixture.ownerId,
        financialAccountId: fixture.account.id,
        operationRequestId: requestId,
        overpaymentApprovalId: approvalId,
      ),
    );

    expect(collection.settledAmountQirsh, 1000);
    expect(collection.advanceAmountQirsh, 200);
    expect(await fixture.ledger.balanceForCustomer(fixture.customerId), 0);
    final advance = (await fixture.ledger.listAdvances()).single;
    expect(await fixture.ledger.remainingAdvanceQirsh(advance.id), 200);
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.account.id),
      2200,
    );

    await fixture.ledger.createCreditSaleEntry(
      sale: SaleRecord(
        id: 'later-credit-sale',
        productId: 'product', quantityKg: 1, salePriceQirshPerKg: 100,
        totalQirsh: 100, createdByUserId: fixture.ownerId,
        createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement',
        paymentMode: SalePaymentMode.credit, customerId: fixture.customerId,
      ),
      customerId: fixture.customerId,
    );
    await fixture.ledger.applyAdvance(CustomerAdvanceApplicationDraft(
      advanceId: advance.id, customerId: fixture.customerId, amountQirsh: 100,
      date: DateTime(2026, 7, 14), createdByUserId: fixture.ownerId,
      operationRequestId: 'customer-apply-1',
    ));
    expect(await fixture.ledger.remainingAdvanceQirsh(advance.id), 100);
    expect(await fixture.ledger.balanceForCustomer(fixture.customerId), 0);

    await fixture.ledger.refundAdvance(CustomerAdvanceRefundDraft(
      advanceId: advance.id, amountQirsh: 100, date: DateTime(2026, 7, 15),
      createdByUserId: fixture.ownerId, operationRequestId: 'customer-refund-1',
    ));
    expect(await fixture.ledger.remainingAdvanceQirsh(advance.id), 0);
    expect(
      await fixture.accounts.currentBalanceForAccount(fixture.account.id),
      2100,
    );
    await expectLater(
      fixture.ledger.refundAdvance(CustomerAdvanceRefundDraft(
        advanceId: advance.id, amountQirsh: 1, date: DateTime(2026, 7, 15),
        createdByUserId: fixture.ownerId, operationRequestId: 'customer-refund-over',
      )),
      throwsA(isA<StateError>()),
    );
  });

  test('customer application reversal restores advance and receivable', () async {
    final fixture = await _CustomerAdvanceFixture.create();
    const requestId = 'customer-overpay-reversal';
    final approvalId = await fixture.approve(requestId: requestId, amountQirsh: 200, expectedBalanceAfterQirsh: 2200);
    await fixture.ledger.createCollection(CustomerCollectionDraft(
      customerId: fixture.customerId, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: fixture.ownerId, financialAccountId: fixture.account.id,
      operationRequestId: requestId, overpaymentApprovalId: approvalId,
    ));
    final advance = (await fixture.ledger.listAdvances()).single;
    await fixture.ledger.createCreditSaleEntry(sale: SaleRecord(
      id: 'reverse-sale', productId: 'product', quantityKg: 1, salePriceQirshPerKg: 100,
      totalQirsh: 100, createdByUserId: fixture.ownerId, createdAt: DateTime(2026, 7, 14),
      stockMovementId: 'movement', paymentMode: SalePaymentMode.credit, customerId: fixture.customerId,
    ), customerId: fixture.customerId);
    final application = await fixture.ledger.applyAdvance(CustomerAdvanceApplicationDraft(
      advanceId: advance.id, customerId: fixture.customerId, amountQirsh: 100,
      date: DateTime(2026, 7, 14), createdByUserId: fixture.ownerId, operationRequestId: 'apply-reversal',
    ));
    final entriesBefore = (await fixture.ledger.listEntries()).length;
    await fixture.ledger.reverseAdvanceApplication(
      user: fixture.ownerUser, applicationId: application.id, reason: 'Correction', operationRequestId: 'reverse-application',
    );
    final reversed = (await fixture.ledger.listAdvanceApplications()).single;
    expect(reversed.isReversed, isTrue);
    expect(reversed.reversalLedgerEntryId, isNotNull);
    expect(await fixture.ledger.remainingAdvanceQirsh(advance.id), 200);
    expect(await fixture.ledger.balanceForCustomer(fixture.customerId), 100);
    final entries = await fixture.ledger.listEntries();
    expect(entries.length, entriesBefore + 1);
    expect(entries.last.type, CustomerAccountEntryType.advanceApplicationReversal);
    expect(entries.last.debitAmountQirsh, 100);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), 2200);
    await fixture.ledger.reverseAdvanceApplication(user: fixture.ownerUser, applicationId: application.id, reason: 'Correction', operationRequestId: 'reverse-application');
    expect((await fixture.ledger.listEntries()).length, entriesBefore + 1);
  });

  test('supplier application reversal restores advance and payable', () async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(name: 'Owner', phone: '01000000001', password: 'secret');
    final approvals = NegativeBalanceApprovalService(authRepository: auth, approvalRepository: LocalNegativeBalanceApprovalRepository(), auditLogRepository: audit);
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit, negativeBalanceApprovalService: approvals);
    final account = await accounts.createAccount(FinancialAccountDraft(name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id));
    await accounts.setOpeningBalance(accountId: account.id, amountQirsh: 2000, effectiveDate: DateTime(2026), createdByUserId: owner.id);
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(const SupplierDraft(name: 'Supplier'));
    final ledger = LocalSupplierAccountRepository(supplierRepository: suppliers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await ledger.createOpeningBalanceEntry(supplierId: supplier.id, amountQirsh: 1000, createdByUserId: owner.id);
    final approvalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 200, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: 'supplier-overpay', sourceDocumentType: 'supplierOverpayment',
      balanceBeforeQirsh: 2000, expectedBalanceAfterQirsh: 800, reason: 'Advance',
    ), ownerPhone: '01000000001', ownerPassword: 'secret');
    await ledger.createPayment(SupplierPaymentDraft(supplierId: supplier.id, date: DateTime(2026, 7, 13), amountQirsh: 1200, createdByUserId: owner.id, financialAccountId: account.id, operationRequestId: 'supplier-overpay', overpaymentApprovalId: approvalId));
    final advance = (await ledger.listAdvances()).single;
    await ledger.createPurchaseEntry(purchase: PurchaseIntake(id: 'supplier-payable', supplierId: supplier.id, productId: 'product', quantityKg: 1, entryUnit: GrainUnit.kilogram, unitPricePiastersPerKg: 100, totalAmountPiasters: 100, createdByUserId: owner.id, createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement'));
    final application = await ledger.applyAdvance(SupplierAdvanceApplicationDraft(advanceId: advance.id, supplierId: supplier.id, amountQirsh: 100, date: DateTime(2026, 7, 14), createdByUserId: owner.id, operationRequestId: 'supplier-apply'));
    final entriesBefore = (await ledger.listEntries()).length;
    final balanceBefore = await accounts.currentBalanceForAccount(account.id);
    await ledger.reverseAdvanceApplication(user: owner, applicationId: application.id, reason: 'Correction', operationRequestId: 'supplier-reverse');
    final reversed = (await ledger.listAdvanceApplications()).single;
    expect(reversed.isReversed, isTrue);
    expect(reversed.reversalLedgerEntryId, isNotNull);
    expect(await ledger.remainingAdvanceQirsh(advance.id), 200);
    expect(await ledger.balanceForSupplier(supplier.id), 100);
    final entries = await ledger.listEntries();
    expect(entries.length, entriesBefore + 1);
    final reversal = entries.singleWhere((entry) => entry.id == reversed.reversalLedgerEntryId);
    expect(reversal.type, SupplierAccountEntryType.advanceApplicationReversal);
    expect(reversal.debitAmountQirsh, 100);
    expect(reversal.creditAmountQirsh, 0);
    expect(await accounts.currentBalanceForAccount(account.id), balanceBefore);
    await ledger.reverseAdvanceApplication(user: owner, applicationId: application.id, reason: 'Correction', operationRequestId: 'supplier-reverse');
    expect((await ledger.listEntries()).length, entriesBefore + 1);
  });

  test('concurrent customer application reversals apply once', () async {
    final fixture = await _CustomerAdvanceFixture.create();
    const overpayRequest = 'customer-concurrent-overpay';
    final approvalId = await fixture.approve(requestId: overpayRequest, amountQirsh: 200, expectedBalanceAfterQirsh: 2200);
    await fixture.ledger.createCollection(CustomerCollectionDraft(customerId: fixture.customerId, date: DateTime(2026, 7, 13), amountQirsh: 1200, createdByUserId: fixture.ownerId, financialAccountId: fixture.account.id, operationRequestId: overpayRequest, overpaymentApprovalId: approvalId));
    final advance = (await fixture.ledger.listAdvances()).single;
    await fixture.ledger.createCreditSaleEntry(sale: SaleRecord(id: 'concurrent-sale', productId: 'product', quantityKg: 1, salePriceQirshPerKg: 100, totalQirsh: 100, createdByUserId: fixture.ownerId, createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement', paymentMode: SalePaymentMode.credit, customerId: fixture.customerId), customerId: fixture.customerId);
    final application = await fixture.ledger.applyAdvance(CustomerAdvanceApplicationDraft(advanceId: advance.id, customerId: fixture.customerId, amountQirsh: 100, date: DateTime(2026, 7, 14), createdByUserId: fixture.ownerId, operationRequestId: 'concurrent-apply'));
    const firstId = 'customer-concurrent-reversal-1';
    const secondId = 'customer-concurrent-reversal-2';
    expect(firstId, isNot(secondId));
    Future<Object> attempt(String requestId) async { try { return await fixture.ledger.reverseAdvanceApplication(user: fixture.ownerUser, applicationId: application.id, reason: 'Correction', operationRequestId: requestId); } catch (error) { return error; } }
    final results = await Future.wait([attempt(firstId), attempt(secondId)]);
    expect(results.whereType<CustomerAdvanceApplication>().length, 1);
    expect(results.whereType<StateError>().length, 1);
    expect(await fixture.ledger.remainingAdvanceQirsh(advance.id), 200);
    expect(await fixture.ledger.balanceForCustomer(fixture.customerId), 100);
    final entries = await fixture.ledger.listEntries();
    expect(entries.where((entry) => entry.type == CustomerAccountEntryType.advanceApplicationReversal).length, 1);
    expect((await fixture.ledger.listAdvanceApplications()).single.isReversed, isTrue);
  });

  test('concurrent supplier application reversals apply once', () async {
    final audit = LocalAuditLogRepository(); final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(name: 'Owner', phone: '01000000002', password: 'secret');
    final approvals = NegativeBalanceApprovalService(authRepository: auth, approvalRepository: LocalNegativeBalanceApprovalRepository(), auditLogRepository: audit);
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit, negativeBalanceApprovalService: approvals);
    final account = await accounts.createAccount(FinancialAccountDraft(name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id));
    await accounts.setOpeningBalance(accountId: account.id, amountQirsh: 2000, effectiveDate: DateTime(2026), createdByUserId: owner.id);
    final suppliers = LocalSupplierRepository(); final supplier = await suppliers.createSupplier(const SupplierDraft(name: 'Supplier'));
    final ledger = LocalSupplierAccountRepository(supplierRepository: suppliers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await ledger.createOpeningBalanceEntry(supplierId: supplier.id, amountQirsh: 1000, createdByUserId: owner.id);
    final approvalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id, amountQirsh: 200, operationType: NegativeBalanceOperationType.supplierOverpayment, sourceDocumentId: 'supplier-concurrent-overpay', sourceDocumentType: 'supplierOverpayment', balanceBeforeQirsh: 2000, expectedBalanceAfterQirsh: 800, reason: 'Advance'), ownerPhone: '01000000002', ownerPassword: 'secret');
    await ledger.createPayment(SupplierPaymentDraft(supplierId: supplier.id, date: DateTime(2026, 7, 13), amountQirsh: 1200, createdByUserId: owner.id, financialAccountId: account.id, operationRequestId: 'supplier-concurrent-overpay', overpaymentApprovalId: approvalId));
    final advance = (await ledger.listAdvances()).single;
    await ledger.createPurchaseEntry(purchase: PurchaseIntake(id: 'supplier-concurrent-payable', supplierId: supplier.id, productId: 'product', quantityKg: 1, entryUnit: GrainUnit.kilogram, unitPricePiastersPerKg: 100, totalAmountPiasters: 100, createdByUserId: owner.id, createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement'));
    final application = await ledger.applyAdvance(SupplierAdvanceApplicationDraft(advanceId: advance.id, supplierId: supplier.id, amountQirsh: 100, date: DateTime(2026, 7, 14), createdByUserId: owner.id, operationRequestId: 'supplier-concurrent-apply'));
    Future<Object> attempt(String requestId) async { try { return await ledger.reverseAdvanceApplication(user: owner, applicationId: application.id, reason: 'Correction', operationRequestId: requestId); } catch (error) { return error; } }
    final results = await Future.wait([attempt('supplier-concurrent-reversal-1'), attempt('supplier-concurrent-reversal-2')]);
    expect(results.whereType<SupplierAdvanceApplication>().length, 1); expect(results.whereType<StateError>().length, 1);
    expect(await ledger.remainingAdvanceQirsh(advance.id), 200); expect(await ledger.balanceForSupplier(supplier.id), 100);
    final entries = await ledger.listEntries(); final reversals = entries.where((entry) => entry.type == SupplierAccountEntryType.advanceApplicationReversal).toList();
    expect(reversals, hasLength(1)); expect(reversals.single.debitAmountQirsh, 100); expect(reversals.single.creditAmountQirsh, 0);
  });

  test('customer and supplier application reversal request namespaces are isolated', () async {
    final fixture = await _NamespaceIsolationFixture.create();

    expect(fixture.customerAdvance.id, isNot(fixture.supplierAdvance.id));
    expect(fixture.customerApplication.id, isNot(fixture.supplierApplication.id));
    expect(fixture.customerId, isNot(fixture.supplierId));

    final customerEntriesBefore = (await fixture.customerLedger.listEntries()).length;
    final supplierEntriesBefore = (await fixture.supplierLedger.listEntries()).length;
    final customerAdvanceBefore = await fixture.customerLedger.remainingAdvanceQirsh(fixture.customerAdvance.id);
    final supplierAdvanceBefore = await fixture.supplierLedger.remainingAdvanceQirsh(fixture.supplierAdvance.id);
    final customerBalanceBefore = await fixture.customerLedger.balanceForCustomer(fixture.customerId);
    final supplierBalanceBefore = await fixture.supplierLedger.balanceForSupplier(fixture.supplierId);
    final financialBalanceBefore = await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id);
    final auditBefore = (await fixture.audit.listLogs()).length;

    expect(customerAdvanceBefore, 100);
    expect(supplierAdvanceBefore, 100);
    expect(customerBalanceBefore, 0);
    expect(supplierBalanceBefore, 0);

    const sharedRequestId = 'shared-application-reversal-request';

    final customerResult = await fixture.customerLedger.reverseAdvanceApplication(
      user: fixture.ownerUser,
      applicationId: fixture.customerApplication.id,
      reason: 'Namespace isolation test',
      operationRequestId: sharedRequestId,
    );

    final supplierResult = await fixture.supplierLedger.reverseAdvanceApplication(
      user: fixture.ownerUser,
      applicationId: fixture.supplierApplication.id,
      reason: 'Namespace isolation test',
      operationRequestId: sharedRequestId,
    );

    expect(customerResult, isA<CustomerAdvanceApplication>());
    expect(supplierResult, isA<SupplierAdvanceApplication>());
    expect(customerResult.id, isNot(supplierResult.id));

    expect(customerResult.isReversed, isTrue);
    expect(supplierResult.isReversed, isTrue);
    expect(customerResult.reversalLedgerEntryId, isNotNull);
    expect(supplierResult.reversalLedgerEntryId, isNotNull);

    expect(await fixture.customerLedger.remainingAdvanceQirsh(fixture.customerAdvance.id), 200);
    expect(await fixture.supplierLedger.remainingAdvanceQirsh(fixture.supplierAdvance.id), 200);
    expect(await fixture.customerLedger.balanceForCustomer(fixture.customerId), 100);
    expect(await fixture.supplierLedger.balanceForSupplier(fixture.supplierId), 100);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id), financialBalanceBefore);

    final customerEntries = await fixture.customerLedger.listEntries();
    final supplierEntries = await fixture.supplierLedger.listEntries();
    expect(customerEntries.length, customerEntriesBefore + 1);
    expect(supplierEntries.length, supplierEntriesBefore + 1);

    final customerReversals = customerEntries.where(
      (e) => e.type == CustomerAccountEntryType.advanceApplicationReversal,
    ).toList();
    final supplierReversals = supplierEntries.where(
      (e) => e.type == SupplierAccountEntryType.advanceApplicationReversal,
    ).toList();
    expect(customerReversals, hasLength(1));
    expect(supplierReversals, hasLength(1));
    expect(customerReversals.single.debitAmountQirsh, 100);
    expect(customerReversals.single.creditAmountQirsh, 0);
    expect(supplierReversals.single.debitAmountQirsh, 100);
    expect(supplierReversals.single.creditAmountQirsh, 0);

    final customerEntry = customerReversals.single;
    final supplierEntry = supplierReversals.single;
    expect(customerResult.reversalLedgerEntryId, customerEntry.id);
    expect(supplierResult.reversalLedgerEntryId, supplierEntry.id);

    expect(customerEntry.sourceDocumentType, 'customerAdvanceApplicationReversal');
    expect(customerEntry.sourceDocumentId, fixture.customerApplication.id);
    expect(supplierEntry.sourceDocumentType, 'supplierAdvanceApplicationReversal');
    expect(supplierEntry.sourceDocumentId, fixture.supplierApplication.id);

    expect(customerEntry.id, isNot(supplierEntry.id));

    final customerApplications = await fixture.customerLedger.listAdvanceApplications();
    expect(customerApplications, hasLength(1));
    expect(customerApplications.single.id, fixture.customerApplication.id);
    expect(customerApplications.single.reversalLedgerEntryId, customerEntry.id);

    final supplierApplications = await fixture.supplierLedger.listAdvanceApplications();
    expect(supplierApplications, hasLength(1));
    expect(supplierApplications.single.id, fixture.supplierApplication.id);
    expect(supplierApplications.single.reversalLedgerEntryId, supplierEntry.id);

    final supplierOriginalEntries = supplierEntries.where(
      (e) => e.type == SupplierAccountEntryType.advanceApplication,
    ).toList();
    expect(supplierOriginalEntries, hasLength(1));
    expect(supplierOriginalEntries.single.debitAmountQirsh, 0);
    expect(supplierOriginalEntries.single.creditAmountQirsh, 100);
    expect(supplierOriginalEntries.single.sourceDocumentType, 'supplierAdvanceApplication');

    final customerOriginalEntries = customerEntries.where(
      (e) => e.type == CustomerAccountEntryType.advanceApplication,
    ).toList();
    expect(customerOriginalEntries, hasLength(1));
    expect(customerOriginalEntries.single.debitAmountQirsh, 0);
    expect(customerOriginalEntries.single.creditAmountQirsh, 100);

    final customerFinancialEntries = await fixture.accounts.statementForAccount(fixture.financialAccount.id);
    final customerLinkedFinancial = customerFinancialEntries.lines.where(
      (l) => l.entry.sourceDocumentId == fixture.customerCollection.id,
    );
    final supplierLinkedFinancial = customerFinancialEntries.lines.where(
      (l) => l.entry.sourceDocumentId == fixture.supplierPayment.id,
    );
    expect(customerLinkedFinancial, hasLength(1));
    expect(supplierLinkedFinancial, hasLength(1));

    final replayCustomerResult = await fixture.customerLedger.reverseAdvanceApplication(
      user: fixture.ownerUser,
      applicationId: fixture.customerApplication.id,
      reason: 'Namespace isolation test',
      operationRequestId: sharedRequestId,
    );
    expect(replayCustomerResult.id, customerResult.id);
    expect(replayCustomerResult.reversalLedgerEntryId, customerResult.reversalLedgerEntryId);
    expect((await fixture.customerLedger.listAdvanceApplications()).single.reversalLedgerEntryId, customerEntry.id);

    final replaySupplierResult = await fixture.supplierLedger.reverseAdvanceApplication(
      user: fixture.ownerUser,
      applicationId: fixture.supplierApplication.id,
      reason: 'Namespace isolation test',
      operationRequestId: sharedRequestId,
    );
    expect(replaySupplierResult.id, supplierResult.id);
    expect(replaySupplierResult.reversalLedgerEntryId, supplierResult.reversalLedgerEntryId);
    expect((await fixture.supplierLedger.listAdvanceApplications()).single.reversalLedgerEntryId, supplierEntry.id);

    expect(await fixture.customerLedger.remainingAdvanceQirsh(fixture.customerAdvance.id), 200);
    expect(await fixture.supplierLedger.remainingAdvanceQirsh(fixture.supplierAdvance.id), 200);
    expect(await fixture.customerLedger.balanceForCustomer(fixture.customerId), 100);
    expect(await fixture.supplierLedger.balanceForSupplier(fixture.supplierId), 100);
    expect((await fixture.customerLedger.listEntries()).length, customerEntriesBefore + 1);
    expect((await fixture.supplierLedger.listEntries()).length, supplierEntriesBefore + 1);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id), financialBalanceBefore);

    final customerReversalAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'customer.advance.application.reversed',
    ).toList();
    final supplierReversalAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'supplier.advance.application.reversed',
    ).toList();
    expect(customerReversalAudits, hasLength(1));
    expect(supplierReversalAudits, hasLength(1));
    expect(customerReversalAudits.single.referenceId, fixture.customerApplication.id);
    expect(supplierReversalAudits.single.referenceId, fixture.supplierApplication.id);
    expect((await fixture.audit.listLogs()).length, auditBefore + 2);
  });

  test('customer refund reversal restores advance and financial balance', () async {
    final fixture = await _CustomerRefundReversalFixture.create();
    final advanceBefore = await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id);
    final financialBefore = await fixture.accounts.currentBalanceForAccount(fixture.account.id);
    expect(advanceBefore, 100);
    expect(financialBefore, 2100);
    final entriesBefore = (await fixture.ledger.listEntries()).length;
    final auditBefore = (await fixture.audit.listLogs()).length;

    final result = await fixture.ledger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.refund.id,
      reason: 'Test reversal', operationRequestId: 'customer-refund-reverse-1',
    );
    expect(result.isReversed, isTrue);
    expect(result.reversalFinancialEntryId, isNotNull);
    expect(result.reversalReason, 'Test reversal');

    expect(await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 200);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), 2200);

    expect((await fixture.ledger.listEntries()).length, entriesBefore);

    final financialStatement = await fixture.accounts.statementForAccount(fixture.account.id);
    final reversalFinancials = financialStatement.lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.customerAdvanceRefundReversal,
    ).toList();
    expect(reversalFinancials, hasLength(1));
    expect(reversalFinancials.single.entry.direction, FinancialAccountEntryDirection.inflow);
    expect(reversalFinancials.single.entry.amountQirsh, 100);
    expect(reversalFinancials.single.entry.reversalOf, fixture.refund.financialEntryId);

    expect(await fixture.ledger.balanceForCustomer(fixture.customerId), 0);

    final refundAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'customer.advance.refund.reversed',
    ).toList();
    expect(refundAudits, hasLength(1));
    expect(refundAudits.single.referenceId, fixture.refund.id);
    expect((await fixture.audit.listLogs()).length, auditBefore + 2);

    final replayResult = await fixture.ledger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.refund.id,
      reason: 'Test reversal', operationRequestId: 'customer-refund-reverse-1',
    );
    expect(replayResult.id, result.id);
    expect(replayResult.reversalFinancialEntryId, result.reversalFinancialEntryId);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), 2200);
    expect((await fixture.ledger.listEntries()).length, entriesBefore);
    expect((await fixture.audit.listLogs()).length, auditBefore + 2);
  });

  test('supplier refund reversal restores advance and financial balance', () async {
    final fixture = await _SupplierRefundReversalFixture.create();
    final advanceBefore = await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id);
    final financialBefore = await fixture.accounts.currentBalanceForAccount(fixture.account.id);
    expect(advanceBefore, 100);
    expect(financialBefore, -100);
    final entriesBefore = (await fixture.ledger.listEntries()).length;
    final auditBefore = (await fixture.audit.listLogs()).length;

    final reversalApprovalId = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.account.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: 'supplier-refund-reverse-1', sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: -100, expectedBalanceAfterQirsh: -200, reason: 'Reversal',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');

    final result = await fixture.ledger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.refund.id,
      reason: 'Test reversal', operationRequestId: 'supplier-refund-reverse-1',
      overpaymentApprovalId: reversalApprovalId,
    );
    expect(result.isReversed, isTrue);
    expect(result.reversalFinancialEntryId, isNotNull);
    expect(result.reversalReason, 'Test reversal');

    expect(await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 200);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), -200);

    expect((await fixture.ledger.listEntries()).length, entriesBefore);

    final financialStatement = await fixture.accounts.statementForAccount(fixture.account.id);
    final reversalFinancials = financialStatement.lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.supplierAdvanceRefundReversal,
    ).toList();
    expect(reversalFinancials, hasLength(1));
    expect(reversalFinancials.single.entry.direction, FinancialAccountEntryDirection.outflow);
    expect(reversalFinancials.single.entry.amountQirsh, 100);
    expect(reversalFinancials.single.entry.reversalOf, fixture.refund.financialEntryId);

    expect(await fixture.ledger.balanceForSupplier(fixture.supplierId), 0);

    final refundAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'supplier.advance.refund.reversed',
    ).toList();
    expect(refundAudits, hasLength(1));
    expect(refundAudits.single.referenceId, fixture.refund.id);
    expect((await fixture.audit.listLogs()).length, auditBefore + 5);

    final replayApprovalId = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.account.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: 'supplier-refund-reverse-1', sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: -200, expectedBalanceAfterQirsh: -200, reason: 'Reversal',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');
    final replayResult = await fixture.ledger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.refund.id,
      reason: 'Test reversal', operationRequestId: 'supplier-refund-reverse-1',
      overpaymentApprovalId: replayApprovalId,
    );
    expect(replayResult.id, result.id);
    expect(replayResult.reversalFinancialEntryId, result.reversalFinancialEntryId);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), -200);
    expect((await fixture.ledger.listEntries()).length, entriesBefore);
    expect((await fixture.audit.listLogs()).length, auditBefore + 6);
  });

  test('concurrent customer refund reversals apply once', () async {
    final fixture = await _CustomerRefundReversalFixture.create();
    const firstId = 'customer-refund-concurrent-1';
    const secondId = 'customer-refund-concurrent-2';
    expect(firstId, isNot(secondId));
    Future<Object> attempt(String requestId) async {
      try {
        return await fixture.ledger.reverseAdvanceRefund(
          user: fixture.ownerUser, refundId: fixture.refund.id,
          reason: 'Concurrent test', operationRequestId: requestId,
        );
      } catch (error) {
        return error;
      }
    }
    final results = await Future.wait([attempt(firstId), attempt(secondId)]);
    expect(results.whereType<CustomerAdvanceRefund>().length, 1);
    expect(results.whereType<StateError>().length, 1);
    expect(await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 200);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), 2200);
    final refundReversals = (await fixture.accounts.statementForAccount(fixture.account.id)).lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.customerAdvanceRefundReversal,
    ).toList();
    expect(refundReversals, hasLength(1));
    expect((await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'customer.advance.refund.reversed',
    ), hasLength(1));
  });

  test('concurrent supplier refund reversals apply once', () async {
    final fixture = await _SupplierRefundReversalFixture.create();
    const firstId = 'supplier-refund-concurrent-1';
    const secondId = 'supplier-refund-concurrent-2';
    expect(firstId, isNot(secondId));

    final reversalApprovalId1 = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.account.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: firstId, sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: -100, expectedBalanceAfterQirsh: -200, reason: 'Concurrent',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');
    final reversalApprovalId2 = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.account.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: secondId, sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: -100, expectedBalanceAfterQirsh: -200, reason: 'Concurrent',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');

    Future<Object> attempt(String requestId, String approvalId) async {
      try {
        return await fixture.ledger.reverseAdvanceRefund(
          user: fixture.ownerUser, refundId: fixture.refund.id,
          reason: 'Concurrent test', operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
        );
      } catch (error) {
        return error;
      }
    }
    final results = await Future.wait([attempt(firstId, reversalApprovalId1), attempt(secondId, reversalApprovalId2)]);
    expect(results.whereType<SupplierAdvanceRefund>().length, 1);
    expect(results.whereType<StateError>().length, 1);
    expect(await fixture.ledger.remainingAdvanceQirsh(fixture.advance.id), 200);
    expect(await fixture.accounts.currentBalanceForAccount(fixture.account.id), -200);
    final refundReversals = (await fixture.accounts.statementForAccount(fixture.account.id)).lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.supplierAdvanceRefundReversal,
    ).toList();
    expect(refundReversals, hasLength(1));
    expect((await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'supplier.advance.refund.reversed',
    ), hasLength(1));
  });

  test('customer and supplier refund reversal request namespaces are isolated', () async {
    final fixture = await _BothRefundReversalFixture.create();
    const sharedRequestId = 'shared-refund-reversal-request';

    final customerEntriesBefore = (await fixture.customerLedger.listEntries()).length;
    final supplierEntriesBefore = (await fixture.supplierLedger.listEntries()).length;

    final customerResult = await fixture.customerLedger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.customerRefund.id,
      reason: 'Namespace isolation', operationRequestId: sharedRequestId,
    );

    final supplierReversalApprovalId = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.financialAccount.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: '$sharedRequestId-supplier', sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id),
      expectedBalanceAfterQirsh: await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id) - 100,
      reason: 'Namespace isolation',
    ), ownerPhone: '01000000083', ownerPassword: 'secret');

    final supplierResult = await fixture.supplierLedger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.supplierRefund.id,
      reason: 'Namespace isolation', operationRequestId: sharedRequestId,
      overpaymentApprovalId: supplierReversalApprovalId,
    );

    expect(customerResult, isA<CustomerAdvanceRefund>());
    expect(supplierResult, isA<SupplierAdvanceRefund>());
    expect(customerResult.id, isNot(supplierResult.id));
    expect(customerResult.isReversed, isTrue);
    expect(supplierResult.isReversed, isTrue);
    expect(customerResult.reversalFinancialEntryId, isNotNull);
    expect(supplierResult.reversalFinancialEntryId, isNotNull);
    expect(customerResult.reversalFinancialEntryId, isNot(supplierResult.reversalFinancialEntryId));

    expect(await fixture.customerLedger.remainingAdvanceQirsh(fixture.customerAdvance.id), 200);
    expect(await fixture.supplierLedger.remainingAdvanceQirsh(fixture.supplierAdvance.id), 200);

    final customerFinancial = (await fixture.accounts.statementForAccount(fixture.financialAccount.id)).lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.customerAdvanceRefundReversal,
    ).toList();
    final supplierFinancial = (await fixture.accounts.statementForAccount(fixture.financialAccount.id)).lines.where(
      (l) => l.entry.sourceType == FinancialAccountEntrySource.supplierAdvanceRefundReversal,
    ).toList();
    expect(customerFinancial, hasLength(1));
    expect(supplierFinancial, hasLength(1));
    expect(customerFinancial.single.entry.direction, FinancialAccountEntryDirection.inflow);
    expect(supplierFinancial.single.entry.direction, FinancialAccountEntryDirection.outflow);
    expect(customerFinancial.single.entry.reversalOf, fixture.customerRefund.financialEntryId);
    expect(supplierFinancial.single.entry.reversalOf, fixture.supplierRefund.financialEntryId);

    expect((await fixture.customerLedger.listEntries()).length, customerEntriesBefore);
    expect((await fixture.supplierLedger.listEntries()).length, supplierEntriesBefore);

    final customerReplay = await fixture.customerLedger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.customerRefund.id,
      reason: 'Namespace isolation', operationRequestId: sharedRequestId,
    );
    expect(customerReplay.id, customerResult.id);

    final supplierReplayApprovalId = await fixture.approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: fixture.ownerUser.id, approvedByOwnerUserId: fixture.ownerUser.id, accountId: fixture.financialAccount.id,
      amountQirsh: 100, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: '$sharedRequestId-supplier-replay', sourceDocumentType: 'supplierAdvanceRefundReversal',
      balanceBeforeQirsh: await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id),
      expectedBalanceAfterQirsh: await fixture.accounts.currentBalanceForAccount(fixture.financialAccount.id) - 100,
      reason: 'Namespace isolation',
    ), ownerPhone: '01000000083', ownerPassword: 'secret');
    final supplierReplay = await fixture.supplierLedger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.supplierRefund.id,
      reason: 'Namespace isolation', operationRequestId: sharedRequestId,
      overpaymentApprovalId: supplierReplayApprovalId,
    );
    expect(supplierReplay.id, supplierResult.id);

    expect((await fixture.customerLedger.listEntries()).length, customerEntriesBefore);
    expect((await fixture.supplierLedger.listEntries()).length, supplierEntriesBefore);

    final customerAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'customer.advance.refund.reversed',
    ).toList();
    final supplierAudits = (await fixture.audit.listLogs()).where(
      (l) => l.actionType == 'supplier.advance.refund.reversed',
    ).toList();
    expect(customerAudits, hasLength(1));
    expect(supplierAudits, hasLength(1));
  });

  test('customer refund reversal rejects non-existent refund', () async {
    final fixture = await _CustomerRefundReversalFixture.create();
    await expectLater(
      fixture.ledger.reverseAdvanceRefund(
        user: fixture.ownerUser, refundId: 'non-existent-refund',
        reason: 'Bad id', operationRequestId: 'bad-refund-id',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('customer refund reversal rejects already reversed refund', () async {
    final fixture = await _CustomerRefundReversalFixture.create();
    await fixture.ledger.reverseAdvanceRefund(
      user: fixture.ownerUser, refundId: fixture.refund.id,
      reason: 'First', operationRequestId: 'first-reverse',
    );
    await expectLater(
      fixture.ledger.reverseAdvanceRefund(
        user: fixture.ownerUser, refundId: fixture.refund.id,
        reason: 'Second', operationRequestId: 'second-reverse',
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _CustomerRefundReversalFixture {
  _CustomerRefundReversalFixture._({
    required this.ownerUser,
    required this.audit,
    required this.accounts,
    required this.account,
    required this.ledger,
    required this.customerId,
    required this.advance,
    required this.refund,
  });

  final dynamic ownerUser;
  final LocalAuditLogRepository audit;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount account;
  final LocalCustomerAccountRepository ledger;
  final String customerId;
  final CustomerAdvance advance;
  final CustomerAdvanceRefund refund;

  static Future<_CustomerRefundReversalFixture> create() async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(name: 'Owner', phone: '01000000081', password: 'secret');
    final approvals = NegativeBalanceApprovalService(authRepository: auth, approvalRepository: LocalNegativeBalanceApprovalRepository(), auditLogRepository: audit);
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit, negativeBalanceApprovalService: approvals);
    final account = await accounts.createAccount(FinancialAccountDraft(name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id));
    await accounts.setOpeningBalance(accountId: account.id, amountQirsh: 1000, effectiveDate: DateTime(2026), createdByUserId: owner.id);

    final customers = LocalCustomerRepository(auditLogRepository: audit);
    final customer = await customers.createCustomer(const CustomerDraft(name: 'Refund Customer'));
    final ledger = LocalCustomerAccountRepository(customerRepository: customers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await ledger.createOpeningBalanceEntry(customerId: customer.id, amountQirsh: 1000, createdByUserId: owner.id);
    final cApprovalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 200, operationType: NegativeBalanceOperationType.customerOverpayment,
      sourceDocumentId: 'refund-customer-overpay', sourceDocumentType: 'customerOverpayment',
      balanceBeforeQirsh: 1000, expectedBalanceAfterQirsh: 2200, reason: 'Advance',
    ), ownerPhone: '01000000081', ownerPassword: 'secret');
    await ledger.createCollection(CustomerCollectionDraft(
      customerId: customer.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: account.id,
      operationRequestId: 'refund-customer-overpay', overpaymentApprovalId: cApprovalId,
    ));
    final advance = (await ledger.listAdvances()).single;
    expect(advance.amountQirsh, 200);
    final refund = await ledger.refundAdvance(CustomerAdvanceRefundDraft(
      advanceId: advance.id, amountQirsh: 100, date: DateTime(2026, 7, 14),
      createdByUserId: owner.id, operationRequestId: 'refund-customer-1',
    ));
    expect(await ledger.remainingAdvanceQirsh(advance.id), 100);
    expect(await accounts.currentBalanceForAccount(account.id), 2100);

    return _CustomerRefundReversalFixture._(
      ownerUser: owner, audit: audit, accounts: accounts,
      account: account, ledger: ledger, customerId: customer.id,
      advance: advance, refund: refund,
    );
  }
}

class _SupplierRefundReversalFixture {
  _SupplierRefundReversalFixture._({
    required this.ownerUser,
    required this.audit,
    required this.accounts,
    required this.approvals,
    required this.account,
    required this.ledger,
    required this.supplierId,
    required this.advance,
    required this.refund,
  });

  final dynamic ownerUser;
  final LocalAuditLogRepository audit;
  final LocalFinancialAccountRepository accounts;
  final NegativeBalanceApprovalService approvals;
  final FinancialAccount account;
  final LocalSupplierAccountRepository ledger;
  final String supplierId;
  final SupplierAdvance advance;
  final SupplierAdvanceRefund refund;

  static Future<_SupplierRefundReversalFixture> create() async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(name: 'Owner', phone: '01000000082', password: 'secret');
    final approvals = NegativeBalanceApprovalService(authRepository: auth, approvalRepository: LocalNegativeBalanceApprovalRepository(), auditLogRepository: audit);
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit, negativeBalanceApprovalService: approvals);
    final account = await accounts.createAccount(FinancialAccountDraft(name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id, allowNegativeBalance: true));
    await accounts.setOpeningBalance(accountId: account.id, amountQirsh: 1000, effectiveDate: DateTime(2026), createdByUserId: owner.id);

    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(const SupplierDraft(name: 'Refund Supplier'));
    final ledger = LocalSupplierAccountRepository(supplierRepository: suppliers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await ledger.createOpeningBalanceEntry(supplierId: supplier.id, amountQirsh: 1000, createdByUserId: owner.id);
    final overpayApprovalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 200, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: 'refund-supplier-overpay', sourceDocumentType: 'supplierOverpayment',
      balanceBeforeQirsh: 1000, expectedBalanceAfterQirsh: -200, reason: 'Advance',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');
    final settlementApprovalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 1200, operationType: NegativeBalanceOperationType.supplierPayment,
      sourceDocumentId: 'refund-supplier-overpay', sourceDocumentType: 'supplierSettlement',
      balanceBeforeQirsh: 1000, expectedBalanceAfterQirsh: -200, reason: 'Settlement',
    ), ownerPhone: '01000000082', ownerPassword: 'secret');
    await ledger.createPayment(SupplierPaymentDraft(
      supplierId: supplier.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: account.id,
      operationRequestId: 'refund-supplier-overpay', overpaymentApprovalId: overpayApprovalId,
      negativeBalanceApprovalId: settlementApprovalId,
    ));
    final advance = (await ledger.listAdvances()).single;
    expect(advance.amountQirsh, 200);
    final refund = await ledger.refundAdvance(SupplierAdvanceRefundDraft(
      advanceId: advance.id, amountQirsh: 100, date: DateTime(2026, 7, 14),
      createdByUserId: owner.id, operationRequestId: 'refund-supplier-1',
    ));
    expect(await ledger.remainingAdvanceQirsh(advance.id), 100);
    expect(await accounts.currentBalanceForAccount(account.id), -100);

    return _SupplierRefundReversalFixture._(
      ownerUser: owner, audit: audit, accounts: accounts,
      approvals: approvals, account: account, ledger: ledger,
      supplierId: supplier.id, advance: advance, refund: refund,
    );
  }
}

class _BothRefundReversalFixture {
  _BothRefundReversalFixture._({
    required this.ownerUser,
    required this.audit,
    required this.accounts,
    required this.approvals,
    required this.financialAccount,
    required this.customerLedger,
    required this.supplierLedger,
    required this.customerAdvance,
    required this.customerRefund,
    required this.supplierAdvance,
    required this.supplierRefund,
  });

  final dynamic ownerUser;
  final LocalAuditLogRepository audit;
  final LocalFinancialAccountRepository accounts;
  final NegativeBalanceApprovalService approvals;
  final FinancialAccount financialAccount;
  final LocalCustomerAccountRepository customerLedger;
  final LocalSupplierAccountRepository supplierLedger;
  final CustomerAdvance customerAdvance;
  final CustomerAdvanceRefund customerRefund;
  final SupplierAdvance supplierAdvance;
  final SupplierAdvanceRefund supplierRefund;

  static Future<_BothRefundReversalFixture> create() async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(name: 'Owner', phone: '01000000083', password: 'secret');
    final approvals = NegativeBalanceApprovalService(authRepository: auth, approvalRepository: LocalNegativeBalanceApprovalRepository(), auditLogRepository: audit);
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit, negativeBalanceApprovalService: approvals);
    final account = await accounts.createAccount(FinancialAccountDraft(name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id));
    await accounts.setOpeningBalance(accountId: account.id, amountQirsh: 2000, effectiveDate: DateTime(2026), createdByUserId: owner.id);

    final customers = LocalCustomerRepository(auditLogRepository: audit);
    final customer = await customers.createCustomer(const CustomerDraft(name: 'NS Refund Cust'));
    final customerLedger = LocalCustomerAccountRepository(customerRepository: customers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await customerLedger.createOpeningBalanceEntry(customerId: customer.id, amountQirsh: 1000, createdByUserId: owner.id);
    final cApprovalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 200, operationType: NegativeBalanceOperationType.customerOverpayment,
      sourceDocumentId: 'ns-refund-cust', sourceDocumentType: 'customerOverpayment',
      balanceBeforeQirsh: 2000, expectedBalanceAfterQirsh: 3200, reason: 'Advance',
    ), ownerPhone: '01000000083', ownerPassword: 'secret');
    await customerLedger.createCollection(CustomerCollectionDraft(
      customerId: customer.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: account.id,
      operationRequestId: 'ns-refund-cust', overpaymentApprovalId: cApprovalId,
    ));
    final customerAdvance = (await customerLedger.listAdvances()).single;
    final customerRefund = await customerLedger.refundAdvance(CustomerAdvanceRefundDraft(
      advanceId: customerAdvance.id, amountQirsh: 100, date: DateTime(2026, 7, 14),
      createdByUserId: owner.id, operationRequestId: 'ns-refund-cust-1',
    ));

    final balanceAfterCustomer = await accounts.currentBalanceForAccount(account.id);
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(const SupplierDraft(name: 'NS Refund Supp'));
    final supplierLedger = LocalSupplierAccountRepository(supplierRepository: suppliers, auditLogRepository: audit, financialAccountRepository: accounts, negativeBalanceApprovalService: approvals);
    await supplierLedger.createOpeningBalanceEntry(supplierId: supplier.id, amountQirsh: 1000, createdByUserId: owner.id);
    final sApprovalId = await approvals.requestApproval(draft: NegativeBalanceApprovalDraft(
      requestedByUserId: owner.id, approvedByOwnerUserId: owner.id, accountId: account.id,
      amountQirsh: 200, operationType: NegativeBalanceOperationType.supplierOverpayment,
      sourceDocumentId: 'ns-refund-supp', sourceDocumentType: 'supplierOverpayment',
      balanceBeforeQirsh: balanceAfterCustomer, expectedBalanceAfterQirsh: balanceAfterCustomer - 1200,
      reason: 'Advance',
    ), ownerPhone: '01000000083', ownerPassword: 'secret');
    await supplierLedger.createPayment(SupplierPaymentDraft(
      supplierId: supplier.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: account.id,
      operationRequestId: 'ns-refund-supp', overpaymentApprovalId: sApprovalId,
      negativeBalanceApprovalId: sApprovalId,
    ));
    final supplierAdvance = (await supplierLedger.listAdvances()).single;
    final supplierRefund = await supplierLedger.refundAdvance(SupplierAdvanceRefundDraft(
      advanceId: supplierAdvance.id, amountQirsh: 100, date: DateTime(2026, 7, 14),
      createdByUserId: owner.id, operationRequestId: 'ns-refund-supp-1',
    ));

    expect(await customerLedger.remainingAdvanceQirsh(customerAdvance.id), 100);
    expect(await supplierLedger.remainingAdvanceQirsh(supplierAdvance.id), 100);

    return _BothRefundReversalFixture._(
      ownerUser: owner, audit: audit, accounts: accounts,
      approvals: approvals, financialAccount: account,
      customerLedger: customerLedger, supplierLedger: supplierLedger,
      customerAdvance: customerAdvance, customerRefund: customerRefund,
      supplierAdvance: supplierAdvance, supplierRefund: supplierRefund,
    );
  }
}

class _CustomerAdvanceFixture {
  _CustomerAdvanceFixture({
    required this.ownerId, required this.customerId, required this.account,
    required this.accounts, required this.ledger, required this.approvals, required this.ownerUser,
  });

  final String ownerId;
  final String customerId;
  final FinancialAccount account;
  final LocalFinancialAccountRepository accounts;
  final LocalCustomerAccountRepository ledger;
  final NegativeBalanceApprovalService approvals;
  final dynamic ownerUser;

  static Future<_CustomerAdvanceFixture> create() async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(
      name: 'Owner', phone: '01000000000', password: 'secret',
    );
    final approvals = NegativeBalanceApprovalService(
      authRepository: auth,
      approvalRepository: LocalNegativeBalanceApprovalRepository(),
      auditLogRepository: audit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit, negativeBalanceApprovalService: approvals,
    );
    final account = await accounts.createAccount(FinancialAccountDraft(
      name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id,
    ));
    await accounts.setOpeningBalance(
      accountId: account.id, amountQirsh: 1000, effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: owner.id,
    );
    final customers = LocalCustomerRepository(auditLogRepository: audit);
    final customer = await customers.createCustomer(const CustomerDraft(name: 'Customer'));
    final ledger = LocalCustomerAccountRepository(
      customerRepository: customers, auditLogRepository: audit,
      financialAccountRepository: accounts, negativeBalanceApprovalService: approvals,
    );
    await ledger.createOpeningBalanceEntry(
      customerId: customer.id, amountQirsh: 1000, createdByUserId: owner.id,
    );
    return _CustomerAdvanceFixture(
      ownerId: owner.id, customerId: customer.id, account: account,
      accounts: accounts, ledger: ledger, approvals: approvals, ownerUser: owner,
    );
  }

  Future<String> approve({
    required String requestId,
    required int amountQirsh,
    required int expectedBalanceAfterQirsh,
  }) => approvals.requestApproval(
    draft: NegativeBalanceApprovalDraft(
      requestedByUserId: ownerId, approvedByOwnerUserId: ownerId,
      accountId: account.id, amountQirsh: amountQirsh,
      operationType: NegativeBalanceOperationType.customerOverpayment,
      sourceDocumentId: requestId, sourceDocumentType: 'customerOverpayment',
      balanceBeforeQirsh: 1000, expectedBalanceAfterQirsh: expectedBalanceAfterQirsh,
      reason: 'Overpayment credit',
    ),
    ownerPhone: '01000000000', ownerPassword: 'secret',
  );
}

class _NamespaceIsolationFixture {
  _NamespaceIsolationFixture._({
    required this.ownerUser,
    required this.audit,
    required this.accounts,
    required this.financialAccount,
    required this.customerLedger,
    required this.supplierLedger,
    required this.customerId,
    required this.supplierId,
    required this.customerAdvance,
    required this.customerApplication,
    required this.customerCollection,
    required this.supplierAdvance,
    required this.supplierApplication,
    required this.supplierPayment,
  });

  final dynamic ownerUser;
  final LocalAuditLogRepository audit;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount financialAccount;
  final LocalCustomerAccountRepository customerLedger;
  final LocalSupplierAccountRepository supplierLedger;
  final String customerId;
  final String supplierId;
  final CustomerAdvance customerAdvance;
  final CustomerAdvanceApplication customerApplication;
  final CustomerCollectionRecord customerCollection;
  final SupplierAdvance supplierAdvance;
  final SupplierAdvanceApplication supplierApplication;
  final SupplierPaymentRecord supplierPayment;

  static Future<_NamespaceIsolationFixture> create() async {
    final audit = LocalAuditLogRepository();
    final auth = LocalAuthRepository.empty();
    final owner = await auth.createFirstOwner(
      name: 'Owner', phone: '01000000099', password: 'secret',
    );
    final approvals = NegativeBalanceApprovalService(
      authRepository: auth,
      approvalRepository: LocalNegativeBalanceApprovalRepository(),
      auditLogRepository: audit,
    );
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit, negativeBalanceApprovalService: approvals,
    );
    final financialAccount = await accounts.createAccount(FinancialAccountDraft(
      name: 'Cash', type: FinancialAccountType.treasury, createdByUserId: owner.id,
    ));
    await accounts.setOpeningBalance(
      accountId: financialAccount.id, amountQirsh: 2000,
      effectiveDate: DateTime(2026), createdByUserId: owner.id,
    );

    final customers = LocalCustomerRepository(auditLogRepository: audit);
    final customer = await customers.createCustomer(const CustomerDraft(name: 'NS Customer'));
    final customerLedger = LocalCustomerAccountRepository(
      customerRepository: customers, auditLogRepository: audit,
      financialAccountRepository: accounts, negativeBalanceApprovalService: approvals,
    );
    await customerLedger.createOpeningBalanceEntry(
      customerId: customer.id, amountQirsh: 1000, createdByUserId: owner.id,
    );

    final customerApprovalId = await approvals.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: owner.id, approvedByOwnerUserId: owner.id,
        accountId: financialAccount.id, amountQirsh: 200,
        operationType: NegativeBalanceOperationType.customerOverpayment,
        sourceDocumentId: 'ns-customer-overpay', sourceDocumentType: 'customerOverpayment',
        balanceBeforeQirsh: 2000, expectedBalanceAfterQirsh: 3200, reason: 'Advance',
      ),
      ownerPhone: '01000000099', ownerPassword: 'secret',
    );
    final customerCollection = await customerLedger.createCollection(CustomerCollectionDraft(
      customerId: customer.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: financialAccount.id,
      operationRequestId: 'ns-customer-overpay', overpaymentApprovalId: customerApprovalId,
    ));
    final customerAdvances = await customerLedger.listAdvances();
    final customerAdvance = customerAdvances.single;
    expect(customerAdvance.amountQirsh, 200);

    await customerLedger.createCreditSaleEntry(
      sale: SaleRecord(
        id: 'ns-customer-sale', productId: 'product', quantityKg: 1,
        salePriceQirshPerKg: 100, totalQirsh: 100, createdByUserId: owner.id,
        createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement',
        paymentMode: SalePaymentMode.credit, customerId: customer.id,
      ),
      customerId: customer.id,
    );
    final customerApplication = await customerLedger.applyAdvance(
      CustomerAdvanceApplicationDraft(
        advanceId: customerAdvance.id, customerId: customer.id, amountQirsh: 100,
        date: DateTime(2026, 7, 14), createdByUserId: owner.id,
        operationRequestId: 'ns-customer-apply',
      ),
    );

    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(const SupplierDraft(name: 'NS Supplier'));
    final supplierLedger = LocalSupplierAccountRepository(
      supplierRepository: suppliers, auditLogRepository: audit,
      financialAccountRepository: accounts, negativeBalanceApprovalService: approvals,
    );
    await supplierLedger.createOpeningBalanceEntry(
      supplierId: supplier.id, amountQirsh: 1000, createdByUserId: owner.id,
    );

    final balanceAfterCustomerCollection = await accounts.currentBalanceForAccount(financialAccount.id);
    final supplierApprovalId = await approvals.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: owner.id, approvedByOwnerUserId: owner.id,
        accountId: financialAccount.id, amountQirsh: 200,
        operationType: NegativeBalanceOperationType.supplierOverpayment,
        sourceDocumentId: 'ns-supplier-overpay', sourceDocumentType: 'supplierOverpayment',
        balanceBeforeQirsh: balanceAfterCustomerCollection,
        expectedBalanceAfterQirsh: balanceAfterCustomerCollection - 1200,
        reason: 'Advance',
      ),
      ownerPhone: '01000000099', ownerPassword: 'secret',
    );
    final supplierPayment = await supplierLedger.createPayment(SupplierPaymentDraft(
      supplierId: supplier.id, date: DateTime(2026, 7, 13), amountQirsh: 1200,
      createdByUserId: owner.id, financialAccountId: financialAccount.id,
      operationRequestId: 'ns-supplier-overpay', overpaymentApprovalId: supplierApprovalId,
      negativeBalanceApprovalId: supplierApprovalId,
    ));
    final supplierAdvances = await supplierLedger.listAdvances();
    final supplierAdvance = supplierAdvances.single;
    expect(supplierAdvance.amountQirsh, 200);

    await supplierLedger.createPurchaseEntry(purchase: PurchaseIntake(
      id: 'ns-supplier-purchase', supplierId: supplier.id, productId: 'product',
      quantityKg: 1, entryUnit: GrainUnit.kilogram, unitPricePiastersPerKg: 100,
      totalAmountPiasters: 100, createdByUserId: owner.id,
      createdAt: DateTime(2026, 7, 14), stockMovementId: 'movement',
    ));
    final supplierApplication = await supplierLedger.applyAdvance(
      SupplierAdvanceApplicationDraft(
        advanceId: supplierAdvance.id, supplierId: supplier.id, amountQirsh: 100,
        date: DateTime(2026, 7, 14), createdByUserId: owner.id,
        operationRequestId: 'ns-supplier-apply',
      ),
    );

    expect(await customerLedger.remainingAdvanceQirsh(customerAdvance.id), 100);
    expect(await supplierLedger.remainingAdvanceQirsh(supplierAdvance.id), 100);
    expect(await customerLedger.balanceForCustomer(customer.id), 0);
    expect(await supplierLedger.balanceForSupplier(supplier.id), 0);

    return _NamespaceIsolationFixture._(
      ownerUser: owner, audit: audit, accounts: accounts,
      financialAccount: financialAccount, customerLedger: customerLedger,
      supplierLedger: supplierLedger, customerId: customer.id,
      supplierId: supplier.id, customerAdvance: customerAdvance,
      customerApplication: customerApplication,
      customerCollection: customerCollection,
      supplierAdvance: supplierAdvance,
      supplierApplication: supplierApplication,
      supplierPayment: supplierPayment,
    );
  }
}
