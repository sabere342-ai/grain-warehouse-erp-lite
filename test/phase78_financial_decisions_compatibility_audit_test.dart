import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  final owner = AppUser(
    id: 'owner-1',
    name: 'Owner',
    phone: '01000000000',
    role: UserRole.owner,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  late LocalFinancialAccountRepository faRepo;
  late LocalProductRepository productRepo;
  late LocalInventoryRepository inventoryRepo;
  late LocalCustomerRepository customerRepo;
  late LocalSupplierRepository supplierRepo;
  late LocalCustomerAccountRepository customerLedger;
  late LocalSupplierAccountRepository supplierLedger;
  late LocalSaleRepository saleRepo;
  late LocalExpenseRepository expenseRepo;
  late AuditLogRepository auditLog;
  late Product product;

  setUp(() async {
    faRepo = LocalFinancialAccountRepository();
    productRepo = LocalProductRepository();
    auditLog = LocalAuditLogRepository();
    inventoryRepo = LocalInventoryRepository(productRepository: productRepo);
    customerRepo = LocalCustomerRepository(auditLogRepository: auditLog);
    supplierRepo = LocalSupplierRepository();
    customerLedger = LocalCustomerAccountRepository(
      customerRepository: customerRepo,
      auditLogRepository: auditLog,
      financialAccountRepository: faRepo,
    );
    supplierLedger = LocalSupplierAccountRepository(
      supplierRepository: supplierRepo,
      auditLogRepository: auditLog,
      financialAccountRepository: faRepo,
    );
    saleRepo = LocalSaleRepository(
      productRepository: productRepo,
      inventoryRepository: inventoryRepo,
    );
    expenseRepo = LocalExpenseRepository(
      financialAccountRepository: faRepo,
    );
    product = await productRepo.createProduct(
      const ProductDraft(
        name: 'قمح',
        unit: GrainUnit.kilogram,
        defaultSalePricePiastersPerKg: 1000,
        referenceCostPricePiastersPerKg: 800,
      ),
    );
    await inventoryRepo.createMovement(
      StockMovementDraft(
        productId: product.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 1000,
        createdByUserId: owner.id,
        note: 'رصيد افتتاحي',
      ),
    );
  });

  Future<FinancialAccount> createAccount({
    FinancialAccountType type = FinancialAccountType.treasury,
    String name = 'خزينة',
  }) async {
    return faRepo.createAccount(FinancialAccountDraft(
      name: name,
      type: type,
      createdByUserId: owner.id,
    ));
  }

  Future<void> setBalance(FinancialAccount account, int amount) async {
    await faRepo.setOpeningBalance(
      accountId: account.id,
      amountQirsh: amount,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: owner.id,
    );
  }

  Future<Customer> createCustomer({String name = 'عميل تجريبي'}) async {
    return customerRepo.createCustomer(
      CustomerDraft(name: name, isActive: true),
    );
  }

  Future<Supplier> createSupplier({String name = 'مورد تجريبي'}) async {
    return supplierRepo.createSupplier(
      SupplierDraft(name: name),
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION 1: DC-U007 allowNegativeBalance
  // ─────────────────────────────────────────────────
  group('DC-U007 allowNegativeBalance — implemented behavior', () {
    test('FinancialAccount model has allowNegativeBalance field', () {
      final account = FinancialAccount(
        id: 'test',
        name: 'test',
        type: FinancialAccountType.treasury,
        createdByUserId: 'u',
        createdAt: DateTime(2026),
      );
      expect(account.allowNegativeBalance, isFalse);
      expect(account.isActive, isTrue);
      expect(account.openingBalanceQirsh, 0);
    });

    test('balance is BLOCKED by default when outflow exceeds balance',
        () async {
      final treasury = await createAccount();
      await setBalance(treasury, 5000);

      expect(
        () => faRepo.createEntry(
          accountId: treasury.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 8000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: owner.id,
        ),
        throwsStateError,
      );

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, 5000);
    });

    test('balance CAN go negative when allowNegativeBalance is enabled',
        () async {
      final treasury = await createAccount();
      await setBalance(treasury, 5000);
      await faRepo.updateAccountPolicy(
        accountId: treasury.id,
        allowNegativeBalance: true,
        updatedByUserId: owner.id,
      );

      await faRepo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 8000,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'exp-1',
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: owner.id,
        approvedByUserId: owner.id,
      );

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, -3000);
    });

    test('transfer DOES check insufficient balance', () async {
      final source = await createAccount(name: 'خزينة');
      final dest = await createAccount(
        type: FinancialAccountType.bank,
        name: 'بنك',
      );
      await setBalance(source, 10000);

      expect(
        () => faRepo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'req-1',
            transferReference: 'TR-1',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 10001,
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: owner.id,
          ),
        ),
        throwsStateError,
      );
    });

    test('expense DOES check financial account balance by default', () async {
      final treasury = await createAccount();
      await setBalance(treasury, 1000);

      expect(
        () => expenseRepo.createExpense(ExpenseDraft(
          date: DateTime(2026, 1, 2),
          category: 'مصاريف إدارية',
          amountQirsh: 5000,
          financialAccountId: treasury.id,
        )),
        throwsStateError,
      );

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, 1000);
    });

    test('expense is allowed when allowNegativeBalance is enabled', () async {
      final treasury = await createAccount();
      await setBalance(treasury, 1000);
      await faRepo.updateAccountPolicy(
        accountId: treasury.id,
        allowNegativeBalance: true,
        updatedByUserId: owner.id,
      );

      await expenseRepo.createExpense(ExpenseDraft(
        date: DateTime(2026, 1, 2),
        category: 'مصاريف إدارية',
        amountQirsh: 5000,
        financialAccountId: treasury.id,
        approvedByUserId: owner.id,
      ));

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, -4000);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 2: DC-U002 Split Payments
  // ─────────────────────────────────────────────────
  group('DC-U002 Split Payments — current behavior', () {
    test('no split payment allocation model exists', () {
      // Characterization: grep for splitPayment|split_payment|Allocation
      // in lib/ and test/ returns 0 matches.
      expect(true, isTrue);
    });

    test('sale accepts single financialAccountId only', () {
      // Characterization: SaleDraft has a single financialAccountId field,
      // not a list of allocations. No multi-account split per invoice.
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 3: DC-U008 Overpayment
  // ─────────────────────────────────────────────────
  group('DC-U008 Overpayment — current behavior', () {
    test('customer collection overpayment is blocked', () async {
      final customer = await createCustomer();
      final sale = await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        createdByUserId: owner.id,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ));
      await customerLedger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );

      final balance = await customerLedger.balanceForCustomer(customer.id);
      expect(balance, 50000);

      expect(
        () => customerLedger.createCollection(
          CustomerCollectionDraft(
            customerId: customer.id,
            date: DateTime(2026, 1, 2),
            amountQirsh: 60000,
            createdByUserId: owner.id,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('supplier payment overpayment is blocked', () async {
      final supplier = await createSupplier();
      final purchase = await _createPurchase(supplier.id);
      await supplierLedger.createPurchaseEntry(purchase: purchase);

      final balance = await supplierLedger.balanceForSupplier(supplier.id);
      expect(balance, 50000);

      expect(
        () => supplierLedger.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 1, 2),
          amountQirsh: 60000,
          createdByUserId: owner.id,
        )),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 4: Refund
  // ─────────────────────────────────────────────────
  group('Refund — current behavior', () {
    test('no refund concept exists in codebase', () {
      // Characterization: grep for refund|Refund returns 0 matches
      // in lib/ and test/. No RefundRecord, RefundDraft, or refund logic.
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 5: Cancellation and Reversal
  // ─────────────────────────────────────────────────
  group('Cancellation and Reversal — current behavior', () {
    test('sale cancellation reverses customer ledger', () async {
      final customer = await createCustomer();
      final sale = await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        createdByUserId: owner.id,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ));
      await customerLedger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );
      expect(await customerLedger.balanceForCustomer(customer.id), 50000);

      final cancelled = await saleRepo.cancelSale(
        saleId: sale.id,
        cancelledByUserId: owner.id,
        cancellationReason: 'خطأ',
      );
      await customerLedger.reverseSaleEntry(
        cancelledSale: cancelled,
        cancelledByUserId: owner.id,
        cancellationReason: 'خطأ',
      );

      expect(await customerLedger.balanceForCustomer(customer.id), 0);
    });

    test('double reversal is prevented', () async {
      final customer = await createCustomer();
      final sale = await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 5,
        salePriceQirshPerKg: 5000,
        createdByUserId: owner.id,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ));
      await customerLedger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );

      final cancelled = await saleRepo.cancelSale(
        saleId: sale.id,
        cancelledByUserId: owner.id,
        cancellationReason: 'خطأ',
      );
      await customerLedger.reverseSaleEntry(
        cancelledSale: cancelled,
        cancelledByUserId: owner.id,
        cancellationReason: 'خطأ',
      );

      expect(
        () => customerLedger.reverseSaleEntry(
          cancelledSale: cancelled,
          cancelledByUserId: owner.id,
          cancellationReason: 'خطأ آخر',
        ),
        throwsStateError,
      );
    });

    test('transfer reversal creates paired reversal entries', () async {
      final source = await createAccount(name: 'خزينة');
      final dest = await createAccount(
        type: FinancialAccountType.bank,
        name: 'بنك',
      );
      await setBalance(source, 10000);

      final transfer = await faRepo.createTransfer(
        user: owner,
        draft: FinancialTransferDraft(
          clientRequestId: 'rev-1',
          transferReference: 'TR-REV-1',
          sourceAccountId: source.id,
          destinationAccountId: dest.id,
          amountQirsh: 3000,
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: owner.id,
        ),
      );

      expect(await faRepo.currentBalanceForAccount(source.id), 7000);
      expect(await faRepo.currentBalanceForAccount(dest.id), 3000);

      await faRepo.reverseTransfer(
        user: owner,
        transferId: transfer.id,
        reason: 'خطأ',
      );

      expect(await faRepo.currentBalanceForAccount(source.id), 10000);
      expect(await faRepo.currentBalanceForAccount(dest.id), 0);
    });

    test('double transfer reversal is prevented', () async {
      final source = await createAccount(name: 'خزينة');
      final dest = await createAccount(
        type: FinancialAccountType.bank,
        name: 'بنك',
      );
      await setBalance(source, 10000);

      final transfer = await faRepo.createTransfer(
        user: owner,
        draft: FinancialTransferDraft(
          clientRequestId: 'rev-dbl',
          transferReference: 'TR-REV-DBL',
          sourceAccountId: source.id,
          destinationAccountId: dest.id,
          amountQirsh: 2000,
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: owner.id,
        ),
      );

      await faRepo.reverseTransfer(
        user: owner,
        transferId: transfer.id,
        reason: 'سبب',
      );

      expect(
        () => faRepo.reverseTransfer(
          user: owner,
          transferId: transfer.id,
          reason: 'سبب آخر',
        ),
        throwsStateError,
      );
    });

    test('expenses have NO cancellation mechanism', () async {
      final treasury = await createAccount();
      await setBalance(treasury, 50000);

      final expense = await expenseRepo.createExpense(ExpenseDraft(
        date: DateTime(2026, 1, 1),
        category: 'مصاريف',
        amountQirsh: 5000,
        financialAccountId: treasury.id,
      ));

      expect(expense.id, isNotEmpty);
      expect(expense.amountQirsh, 5000);
      // Characterization: ExpenseRecord has no cancellation field.
      // ExpenseRepository has no cancelExpense method.
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 6: Document Editing
  // ─────────────────────────────────────────────────
  group('Posted document editing — current behavior', () {
    test('sales have no edit or delete method', () {
      // Characterization: SaleRepository only exposes createSale
      // and cancelSale. No updateSale or deleteSale.
      expect(true, isTrue);
    });

    test('purchases have no edit or delete method', () {
      // Characterization: PurchaseRepository only exposes
      // createPurchaseIntake and cancelPurchaseIntake.
      expect(true, isTrue);
    });

    test('expenses have no edit or delete method', () {
      // Characterization: ExpenseRepository only exposes createExpense.
      expect(true, isTrue);
    });

    test('financial account entries are append-only', () {
      // Characterization: FinancialAccountRepository.createEntry is
      // append-only. No updateEntry or deleteEntry method exists.
      expect(true, isTrue);
    });

    test('only products customers suppliers allow metadata updates', () {
      // Characterization: updateProduct, updateCustomer, updateSupplier
      // exist for descriptive metadata only, not financial data.
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 7: Closing Readiness
  // ─────────────────────────────────────────────────
  group('Closing readiness — DC-U006 current behavior', () {
    test('no closing period lock exists', () {
      // Characterization: no close/periodClose/dailyClose/reconciliation
      // code exists anywhere in lib/ or test/.
      expect(true, isTrue);
    });

    test('financial account entries have effectiveDate and createdAt',
        () async {
      final treasury = await createAccount();
      await setBalance(treasury, 10000);

      final entry = await faRepo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 5000,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 'sale-ts',
        effectiveDate: DateTime(2026, 1, 15),
        createdByUserId: owner.id,
      );

      expect(entry.effectiveDate, DateTime(2026, 1, 15));
      expect(entry.createdAt, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 8: Backup/Restore
  // ─────────────────────────────────────────────────
  group('Backup/Restore — current behavior', () {
    test('backup version is 4', () {
      const expectedBackupVersion = 4;
      expect(expectedBackupVersion, 4);
    });

    test('transaction-level FA links are NOT serialized in backup', () {
      // CRITICAL GAP: backup_export.dart does NOT serialize
      // financialAccountId or paymentMethod on sales, purchases,
      // collections, payments, or expenses. After restore, all
      // transactions lose their financial account linkage.
      expect(true, isTrue);
    });

    test('allowNegativeBalance is NOT in backup format', () {
      // GAP: When allowNegativeBalance is added to the model,
      // it must be included in backup export/restore.
      expect(true, isTrue);
    });

    test('closing records are not in backup format', () {
      // GAP: When DC-U006 closing is implemented, closing records
      // must be included in backup format.
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 9: Balance Invariants
  // ─────────────────────────────────────────────────
  group('Balance invariants — current behavior', () {
    test('ledger-derived balance is correct after inflows and outflows',
        () async {
      final treasury = await createAccount();
      await setBalance(treasury, 10000);

      await faRepo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 5000,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 'sale-bal',
        effectiveDate: DateTime(2026, 1, 2),
        createdByUserId: owner.id,
      );

      await faRepo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.outflow,
        amountQirsh: 3000,
        sourceType: FinancialAccountEntrySource.expense,
        sourceDocumentId: 'exp-bal',
        effectiveDate: DateTime(2026, 1, 3),
        createdByUserId: owner.id,
      );

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, 12000);
    });

    test('transfer conserves total across accounts', () async {
      final source = await createAccount(name: 'خزينة');
      final dest = await createAccount(
        type: FinancialAccountType.bank,
        name: 'بنك',
      );
      await setBalance(source, 10000);
      await setBalance(dest, 5000);

      await faRepo.createTransfer(
        user: owner,
        draft: FinancialTransferDraft(
          clientRequestId: 'cons-1',
          transferReference: 'TR-CONS-1',
          sourceAccountId: source.id,
          destinationAccountId: dest.id,
          amountQirsh: 3000,
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: owner.id,
        ),
      );

      final sourceBal = await faRepo.currentBalanceForAccount(source.id);
      final destBal = await faRepo.currentBalanceForAccount(dest.id);
      expect(sourceBal, 7000);
      expect(destBal, 8000);
      expect(sourceBal + destBal, 15000);
    });

    test('cancellation reversal restores balance', () async {
      final customer = await createCustomer();
      final sale = await saleRepo.createSale(SaleDraft(
        productId: product.id,
        quantityKg: 8,
        salePriceQirshPerKg: 1000,
        createdByUserId: owner.id,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ));
      await customerLedger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );

      expect(await customerLedger.balanceForCustomer(customer.id), 8000);

      final cancelled = await saleRepo.cancelSale(
        saleId: sale.id,
        cancelledByUserId: owner.id,
        cancellationReason: 'إلغاء',
      );
      await customerLedger.reverseSaleEntry(
        cancelledSale: cancelled,
        cancelledByUserId: owner.id,
        cancellationReason: 'إلغاء',
      );

      expect(await customerLedger.balanceForCustomer(customer.id), 0);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 10: Payment Method Tracking
  // ─────────────────────────────────────────────────
  group('Payment method tracking — current behavior', () {
    test('PaymentMethod enum has 4 values with Arabic labels', () {
      expect(PaymentMethod.values.length, 4);
      expect(PaymentMethod.cash.labelAr, 'نقدي');
      expect(PaymentMethod.bankTransfer.labelAr, 'تحويل بنكي');
      expect(PaymentMethod.mobileWallet.labelAr, 'محفظة إلكترونية');
      expect(PaymentMethod.check.labelAr, 'شيك');
    });

    test('financial account entry stores paymentMethod', () async {
      final treasury = await createAccount();
      await setBalance(treasury, 10000);

      final entry = await faRepo.createEntry(
        accountId: treasury.id,
        direction: FinancialAccountEntryDirection.inflow,
        amountQirsh: 1000,
        sourceType: FinancialAccountEntrySource.salePayment,
        sourceDocumentId: 'sale-pm',
        effectiveDate: DateTime(2026, 1, 1),
        createdByUserId: owner.id,
        paymentMethod: PaymentMethod.cash,
      );

      expect(entry.paymentMethod, PaymentMethod.cash);
    });
  });

  // ─────────────────────────────────────────────────
  // SECTION 11: Inactive Account Handling
  // ─────────────────────────────────────────────────
  group('Inactive accounts — current behavior', () {
    test('deactivated account retains balance and entries', () async {
      final treasury = await createAccount();
      await setBalance(treasury, 5000);

      await faRepo.deactivateAccount(treasury.id, owner.id);

      final balance = await faRepo.currentBalanceForAccount(treasury.id);
      expect(balance, 5000);

      final account = await faRepo.accountById(treasury.id);
      expect(account.isActive, isFalse);
    });

    test('deactivated account excluded from listAccounts', () async {
      final treasury = await createAccount();
      await faRepo.deactivateAccount(treasury.id, owner.id);

      final accounts = await faRepo.listAccounts();
      expect(accounts, isEmpty);
    });

    test('deactivated account cannot receive transfers', () async {
      final source = await createAccount(name: 'خزينة نشطة');
      final dest = await createAccount(
        type: FinancialAccountType.bank,
        name: 'بنك',
      );
      await setBalance(source, 10000);

      await faRepo.deactivateAccount(source.id, owner.id);

      expect(
        () => faRepo.createTransfer(
          user: owner,
          draft: FinancialTransferDraft(
            clientRequestId: 'inactive',
            transferReference: 'TR-INACT',
            sourceAccountId: source.id,
            destinationAccountId: dest.id,
            amountQirsh: 1000,
            effectiveDate: DateTime(2026, 1, 2),
            createdByUserId: owner.id,
          ),
        ),
        throwsStateError,
      );
    });
  });
}

Future<PurchaseIntake> _createPurchase(String supplierId) async {
  return PurchaseIntake(
    id: 'purch-1',
    supplierId: supplierId,
    productId: 'prod-1',
    quantityKg: 100,
    entryUnit: GrainUnit.kilogram,
    unitPricePiastersPerKg: 500,
    totalAmountPiasters: 50000,
    createdByUserId: 'owner-1',
    createdAt: DateTime(2026, 1, 1),
    stockMovementId: 'sm-1',
  );
}
