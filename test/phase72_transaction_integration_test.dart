import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
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
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('Phase 72 — Transaction Integration', () {
    group('PaymentMethod enum', () {
      test('labelAr returns Arabic labels for all values', () {
        expect(PaymentMethod.cash.labelAr, 'نقدي');
        expect(PaymentMethod.bankTransfer.labelAr, 'تحويل بنكي');
        expect(PaymentMethod.mobileWallet.labelAr, 'محفظة إلكترونية');
        expect(PaymentMethod.check.labelAr, 'شيك');
      });
    });

    group('FinancialAccountEntrySource new values', () {
      test('labelAr returns Arabic labels for new source types', () {
        expect(FinancialAccountEntrySource.salePayment.labelAr, 'دفعة مبيعات');
        expect(FinancialAccountEntrySource.purchasePayment.labelAr,
            'دفعة مشتريات');
        expect(
          FinancialAccountEntrySource.customerCollection.labelAr,
          'تحصيل من عميل',
        );
        expect(
          FinancialAccountEntrySource.supplierSettlement.labelAr,
          'تسوية مع مورد',
        );
        expect(FinancialAccountEntrySource.expense.labelAr, 'مصروف');
        expect(
          FinancialAccountEntrySource.cancellationReversal.labelAr,
          'عكس إلغاء',
        );
      });
    });

    group('PurchasePaymentMode enum', () {
      test('labelAr returns Arabic labels', () {
        expect(PurchasePaymentMode.credit.labelAr, 'آجل على مورد');
        expect(PurchasePaymentMode.paid.labelAr, 'مدفوع');
        expect(PurchasePaymentMode.partial.labelAr, 'دفع جزئي');
      });
    });

    group('FinancialAccountRepository.createEntry', () {
      late LocalFinancialAccountRepository repo;
      late _ApprovalHarness approvals;

      setUp(() async {
        approvals = _ApprovalHarness();
        repo = LocalFinancialAccountRepository(
          negativeBalanceApprovalService: approvals.service,
        );
        await repo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'owner',
          ),
        );
      });

      test('creates entry with correct fields', () async {
        final accountId = (await repo.listAccounts()).first.id;
        final entry = await repo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdByUserId: 'user-1',
          reference: 'دفعة مبيعات',
          note: 'ملاحظة',
          paymentMethod: PaymentMethod.cash,
        );

        expect(entry.hasValidId, true);
        expect(entry.direction, FinancialAccountEntryDirection.inflow);
        expect(entry.amountQirsh, 5000);
        expect(entry.sourceType, FinancialAccountEntrySource.salePayment);
        expect(entry.sourceDocumentId, 'sale-1');
        expect(entry.reference, 'دفعة مبيعات');
        expect(entry.note, 'ملاحظة');
        expect(entry.paymentMethod, PaymentMethod.cash);
      });

      test('rejects zero amount', () async {
        final accountId = (await repo.listAccounts()).first.id;
        expect(
          () => repo.createEntry(
            accountId: accountId,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: 0,
            sourceType: FinancialAccountEntrySource.salePayment,
            sourceDocumentId: 'sale-1',
            effectiveDate: DateTime(2026),
            createdByUserId: 'user-1',
          ),
          throwsArgumentError,
        );
      });

      test('rejects negative amount', () async {
        final accountId = (await repo.listAccounts()).first.id;
        expect(
          () => repo.createEntry(
            accountId: accountId,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: -100,
            sourceType: FinancialAccountEntrySource.salePayment,
            sourceDocumentId: 'sale-1',
            effectiveDate: DateTime(2026),
            createdByUserId: 'user-1',
          ),
          throwsArgumentError,
        );
      });

      test('rejects non-existent account', () {
        expect(
          () => repo.createEntry(
            accountId: 'non-existent',
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: 1000,
            sourceType: FinancialAccountEntrySource.salePayment,
            sourceDocumentId: 'sale-1',
            effectiveDate: DateTime(2026),
            createdByUserId: 'user-1',
          ),
          throwsStateError,
        );
      });

      test('inflow entry increases balance', () async {
        final accountId = (await repo.listAccounts()).first.id;
        await repo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdByUserId: 'user-1',
        );
        expect(await repo.currentBalanceForAccount(accountId), 5000);
      });

      test('outflow entry decreases balance', () async {
        final account = (await repo.listAccounts()).first;
        final approvalId = await approvals.approve(
          accounts: repo,
          account: account,
          amountQirsh: 3000,
          operationType: NegativeBalanceOperationType.expense,
          sourceDocumentId: 'exp-1',
          sourceDocumentType: FinancialAccountEntrySource.expense.name,
          requesterUserId: 'user-1',
        );
        await repo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 3000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-1',
          effectiveDate: DateTime(2026),
          createdByUserId: 'user-1',
          negativeBalanceApprovalId: approvalId,
        );
        expect(await repo.currentBalanceForAccount(account.id), -3000);
      });
    });

    group('ExpenseRepository → FinancialAccountEntry', () {
      late LocalExpenseRepository expenseRepo;
      late LocalFinancialAccountRepository faRepo;
      late _ApprovalHarness approvals;

      setUp(() async {
        approvals = _ApprovalHarness();
        faRepo = LocalFinancialAccountRepository(
          negativeBalanceApprovalService: approvals.service,
        );
        expenseRepo = LocalExpenseRepository(
          financialAccountRepository: faRepo,
        );
        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'owner',
          ),
        );
      });

      test('creates outflow FA entry when financialAccountId provided',
          () async {
        final account = (await faRepo.listAccounts()).first;
        const operationRequestId = 'expense-phase72-1';
        final approvalId = await approvals.approve(
          accounts: faRepo,
          account: account,
          amountQirsh: 2500,
          operationType: NegativeBalanceOperationType.expense,
          sourceDocumentId: operationRequestId,
          sourceDocumentType: FinancialAccountEntrySource.expense.name,
          requesterUserId: 'system',
        );
        await expenseRepo.createExpense(
          ExpenseDraft(
            date: DateTime(2026, 1, 15),
            category: 'مصاريف إدارية',
            amountQirsh: 2500,
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            negativeBalanceApprovalId: approvalId,
            operationRequestId: operationRequestId,
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(account.id);
        expect(balance, -2500);

        final statement = await faRepo.statementForAccount(account.id);
        expect(statement.lines.length, 1);
        expect(
          statement.lines.first.entry.sourceType,
          FinancialAccountEntrySource.expense,
        );
        expect(
          statement.lines.first.entry.direction,
          FinancialAccountEntryDirection.outflow,
        );
        expect(statement.lines.first.entry.amountQirsh, 2500);
        expect(statement.lines.first.entry.paymentMethod, PaymentMethod.cash);
      });

      test('does NOT create FA entry when financialAccountId is null',
          () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        await expenseRepo.createExpense(
          ExpenseDraft(
            date: DateTime(2026, 1, 15),
            category: 'مصاريف إدارية',
            amountQirsh: 2500,
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });

      test('does NOT create FA entry when financialAccountId is empty',
          () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        await expenseRepo.createExpense(
          ExpenseDraft(
            date: DateTime(2026, 1, 15),
            category: 'مصاريف إدارية',
            amountQirsh: 2500,
            financialAccountId: '',
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });
    });

    group('CustomerAccountRepository.createCollection → FA entry', () {
      late LocalCustomerAccountRepository customerAccountRepo;
      late LocalCustomerRepository customerRepo;
      late LocalFinancialAccountRepository faRepo;

      setUp(() async {
        faRepo = LocalFinancialAccountRepository();
        customerRepo = LocalCustomerRepository();
        customerAccountRepo = LocalCustomerAccountRepository(
          customerRepository: customerRepo,
          financialAccountRepository: faRepo,
        );

        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'حساب بنكي',
            type: FinancialAccountType.bank,
            createdByUserId: 'owner',
          ),
        );

        await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل اختبار'),
        );
      });

      test('creates inflow FA entry when financialAccountId provided',
          () async {
        final customer = (await customerRepo.listCustomers()).first;
        final faAccountId = (await faRepo.listAccounts()).first.id;

        await customerAccountRepo.createCreditSaleEntry(
          sale: SaleRecord(
            id: 'sale-1',
            productId: 'p-1',
            quantityKg: 100,
            salePriceQirshPerKg: 500,
            totalQirsh: 50000,
            createdByUserId: 'user-1',
            createdAt: DateTime(2026),
            stockMovementId: 'sm-1',
            paymentMode: SalePaymentMode.credit,
            customerId: customer.id,
          ),
          customerId: customer.id,
        );

        final balanceBefore =
            await customerAccountRepo.balanceForCustomer(customer.id);
        expect(balanceBefore, 50000);

        final collection = await customerAccountRepo.createCollection(
          CustomerCollectionDraft(
            customerId: customer.id,
            date: DateTime(2026, 2, 1),
            amountQirsh: 30000,
            createdByUserId: 'user-1',
            financialAccountId: faAccountId,
            paymentMethod: PaymentMethod.bankTransfer,
          ),
        );

        expect(collection.financialAccountId, faAccountId);
        expect(collection.paymentMethod, PaymentMethod.bankTransfer);

        final faBalance = await faRepo.currentBalanceForAccount(faAccountId);
        expect(faBalance, 30000);

        final statement = await faRepo.statementForAccount(faAccountId);
        expect(statement.lines.length, 1);
        expect(
          statement.lines.first.entry.sourceType,
          FinancialAccountEntrySource.customerCollection,
        );
        expect(
          statement.lines.first.entry.direction,
          FinancialAccountEntryDirection.inflow,
        );
        expect(statement.lines.first.entry.amountQirsh, 30000);
        expect(
          statement.lines.first.entry.paymentMethod,
          PaymentMethod.bankTransfer,
        );
      });

      test('does NOT create FA entry when financialAccountId is null',
          () async {
        final customer = (await customerRepo.listCustomers()).first;

        await customerAccountRepo.createCreditSaleEntry(
          sale: SaleRecord(
            id: 'sale-2',
            productId: 'p-1',
            quantityKg: 100,
            salePriceQirshPerKg: 500,
            totalQirsh: 50000,
            createdByUserId: 'user-1',
            createdAt: DateTime(2026),
            stockMovementId: 'sm-2',
            paymentMode: SalePaymentMode.credit,
            customerId: customer.id,
          ),
          customerId: customer.id,
        );

        await customerAccountRepo.createCollection(
          CustomerCollectionDraft(
            customerId: customer.id,
            date: DateTime(2026, 2, 1),
            amountQirsh: 20000,
            createdByUserId: 'user-1',
          ),
        );

        final faAccountId = (await faRepo.listAccounts()).first.id;
        final faBalance = await faRepo.currentBalanceForAccount(faAccountId);
        expect(faBalance, 0);
      });
    });

    group('SupplierAccountRepository.createPayment → FA entry', () {
      late LocalSupplierAccountRepository supplierAccountRepo;
      late LocalSupplierRepository supplierRepo;
      late LocalFinancialAccountRepository faRepo;
      late _ApprovalHarness approvals;

      setUp(() async {
        approvals = _ApprovalHarness();
        faRepo = LocalFinancialAccountRepository(
          negativeBalanceApprovalService: approvals.service,
        );
        supplierRepo = LocalSupplierRepository();
        supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          financialAccountRepository: faRepo,
        );

        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'owner',
          ),
        );

        await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد اختبار'),
        );
      });

      test('creates outflow FA entry when financialAccountId provided',
          () async {
        final supplier = (await supplierRepo.listSuppliers()).first;
        final account = (await faRepo.listAccounts()).first;

        await supplierAccountRepo.createPurchaseEntry(
          purchase: PurchaseIntake(
            id: 'pin-1',
            supplierId: supplier.id,
            productId: 'p-1',
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            totalAmountPiasters: 60000,
            createdByUserId: 'user-1',
            createdAt: DateTime(2026),
            stockMovementId: 'sm-1',
            paymentMode: PurchasePaymentMode.credit,
          ),
        );

        final balanceBefore =
            await supplierAccountRepo.balanceForSupplier(supplier.id);
        expect(balanceBefore, 60000);

        const operationRequestId = 'supplier-payment-phase72-1';
        final approvalId = await approvals.approve(
          accounts: faRepo,
          account: account,
          amountQirsh: 40000,
          operationType: NegativeBalanceOperationType.supplierPayment,
          sourceDocumentId: operationRequestId,
          sourceDocumentType:
              FinancialAccountEntrySource.supplierSettlement.name,
          requesterUserId: 'user-1',
        );
        final payment = await supplierAccountRepo.createPayment(
          SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 2, 1),
            amountQirsh: 40000,
            createdByUserId: 'user-1',
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            negativeBalanceApprovalId: approvalId,
            operationRequestId: operationRequestId,
          ),
        );

        expect(payment.financialAccountId, account.id);
        expect(payment.paymentMethod, PaymentMethod.cash);

        final faBalance = await faRepo.currentBalanceForAccount(account.id);
        expect(faBalance, -40000);

        final statement = await faRepo.statementForAccount(account.id);
        expect(statement.lines.length, 1);
        expect(
          statement.lines.first.entry.sourceType,
          FinancialAccountEntrySource.supplierSettlement,
        );
        expect(
          statement.lines.first.entry.direction,
          FinancialAccountEntryDirection.outflow,
        );
        expect(statement.lines.first.entry.amountQirsh, 40000);
        expect(statement.lines.first.entry.paymentMethod, PaymentMethod.cash);
      });

      test('does NOT create FA entry when financialAccountId is null',
          () async {
        final supplier = (await supplierRepo.listSuppliers()).first;

        await supplierAccountRepo.createPurchaseEntry(
          purchase: PurchaseIntake(
            id: 'pin-2',
            supplierId: supplier.id,
            productId: 'p-1',
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            totalAmountPiasters: 60000,
            createdByUserId: 'user-1',
            createdAt: DateTime(2026),
            stockMovementId: 'sm-2',
            paymentMode: PurchasePaymentMode.credit,
          ),
        );

        await supplierAccountRepo.createPayment(
          SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 2, 1),
            amountQirsh: 30000,
            createdByUserId: 'user-1',
          ),
        );

        final faAccountId = (await faRepo.listAccounts()).first.id;
        final faBalance = await faRepo.currentBalanceForAccount(faAccountId);
        expect(faBalance, 0);
      });
    });

    group('SaleController → FinancialAccountEntry', () {
      late SaleController saleController;
      late LocalSaleRepository saleRepo;
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalCustomerRepository customerRepo;
      late LocalCustomerAccountRepository customerAccountRepo;
      late LocalFinancialAccountRepository faRepo;
      late Product product;
      late AppUser owner;

      setUp(() async {
        productRepo = LocalProductRepository();
        customerRepo = LocalCustomerRepository();
        inventoryRepo =
            LocalInventoryRepository(productRepository: productRepo);
        faRepo = LocalFinancialAccountRepository();
        customerAccountRepo = LocalCustomerAccountRepository(
          customerRepository: customerRepo,
          financialAccountRepository: faRepo,
        );
        saleRepo = LocalSaleRepository(
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
        );

        saleController = SaleController(
          saleRepository: saleRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          customerRepository: customerRepo,
          customerAccountRepository: customerAccountRepo,
          financialAccountRepository: faRepo,
        );

        product = await productRepo.createProduct(
          const ProductDraft(
            name: 'قمح',
            unit: GrainUnit.kilogram,
            defaultSalePricePiastersPerKg: 500,
          ),
        );

        await customerRepo.createCustomer(
          const CustomerDraft(name: 'عميل اختبار'),
        );

        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'owner',
          ),
        );

        owner = AppUser(
          id: 'owner-1',
          name: 'المالك',
          phone: '0555',
          role: UserRole.owner,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
      });

      test('cash sale creates inflow FA entry', () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final customerId = (await customerRepo.listCustomers()).first.id;

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        final result = await saleController.createSale(
          user: owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          customerId: customerId,
          paymentMode: SalePaymentMode.cash,
          financialAccountId: accountId,
          paymentMethod: PaymentMethod.cash,
        );
        expect(result, true);

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 50000);

        final statement = await faRepo.statementForAccount(accountId);
        expect(statement.lines.length, 1);
        expect(
          statement.lines.first.entry.sourceType,
          FinancialAccountEntrySource.salePayment,
        );
        expect(
          statement.lines.first.entry.direction,
          FinancialAccountEntryDirection.inflow,
        );
        expect(statement.lines.first.entry.amountQirsh, 50000);
        expect(statement.lines.first.entry.paymentMethod, PaymentMethod.cash);
      });

      test('partial sale creates inflow FA entry for paid portion', () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final customerId = (await customerRepo.listCustomers()).first.id;

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        final result = await saleController.createSale(
          user: owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          customerId: customerId,
          paymentMode: SalePaymentMode.partial,
          paidAmountQirsh: 20000,
          financialAccountId: accountId,
          paymentMethod: PaymentMethod.bankTransfer,
        );
        expect(result, true);

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 20000);

        final statement = await faRepo.statementForAccount(accountId);
        expect(statement.lines.length, 1);
        expect(statement.lines.first.entry.amountQirsh, 20000);
        expect(
          statement.lines.first.entry.paymentMethod,
          PaymentMethod.bankTransfer,
        );
      });

      test('credit sale does NOT create FA entry', () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final customerId = (await customerRepo.listCustomers()).first.id;

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        final result = await saleController.createSale(
          user: owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          customerId: customerId,
          paymentMode: SalePaymentMode.credit,
          financialAccountId: accountId,
        );
        expect(result, true);

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });

      test('sale without financialAccountId does NOT create FA entry',
          () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final customerId = (await customerRepo.listCustomers()).first.id;

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        final result = await saleController.createSale(
          user: owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          customerId: customerId,
          paymentMode: SalePaymentMode.cash,
        );
        expect(result, true);

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });

      test('cancelling cash sale creates outflow reversal FA entry', () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final customerId = (await customerRepo.listCustomers()).first.id;

        await inventoryRepo.createMovement(
          StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.manualIncrease,
            quantityKg: 1000,
            createdByUserId: 'owner-1',
          ),
        );

        await saleController.createSale(
          user: owner,
          productId: product.id,
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          customerId: customerId,
          paymentMode: SalePaymentMode.cash,
          financialAccountId: accountId,
          paymentMethod: PaymentMethod.cash,
        );

        final balanceAfterSale =
            await faRepo.currentBalanceForAccount(accountId);
        expect(balanceAfterSale, 50000);

        final saleId = saleController.sales.first.id;
        await saleController.cancelSale(
          user: owner,
          saleId: saleId,
          cancellationReason: 'خطأ في الطلب',
        );

        final balanceAfterCancel =
            await faRepo.currentBalanceForAccount(accountId);
        expect(balanceAfterCancel, 0);

        final statement = await faRepo.statementForAccount(accountId);
        expect(statement.lines.length, 2);

        final reversalEntry = statement.lines
            .firstWhere(
              (l) =>
                  l.entry.sourceType ==
                  FinancialAccountEntrySource.cancellationReversal,
            )
            .entry;
        expect(reversalEntry.direction, FinancialAccountEntryDirection.outflow);
        expect(reversalEntry.amountQirsh, 50000);
        expect(reversalEntry.reversalOf, saleId);
        expect(reversalEntry.paymentMethod, PaymentMethod.cash);
      });
    });

    group('PurchaseRepository → FinancialAccountEntry', () {
      late LocalPurchaseRepository purchaseRepo;
      late LocalSupplierRepository supplierRepo;
      late LocalProductRepository productRepo;
      late LocalInventoryRepository inventoryRepo;
      late LocalSupplierAccountRepository supplierAccountRepo;
      late LocalFinancialAccountRepository faRepo;
      late Product product;
      late _ApprovalHarness approvals;

      setUp(() async {
        productRepo = LocalProductRepository();
        supplierRepo = LocalSupplierRepository();
        inventoryRepo =
            LocalInventoryRepository(productRepository: productRepo);
        approvals = _ApprovalHarness();
        faRepo = LocalFinancialAccountRepository(
          negativeBalanceApprovalService: approvals.service,
        );
        supplierAccountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          financialAccountRepository: faRepo,
        );
        purchaseRepo = LocalPurchaseRepository(
          supplierRepository: supplierRepo,
          productRepository: productRepo,
          inventoryRepository: inventoryRepo,
          supplierAccountRepository: supplierAccountRepo,
          financialAccountRepository: faRepo,
        );

        product = await productRepo.createProduct(
          const ProductDraft(
            name: 'قمح',
            unit: GrainUnit.kilogram,
          ),
        );

        await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد اختبار'),
        );

        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            allowNegativeBalance: true,
            createdByUserId: 'owner',
          ),
        );
      });

      test('paid purchase creates outflow FA entry', () async {
        final supplier = (await supplierRepo.listSuppliers()).first;
        final account = (await faRepo.listAccounts()).first;
        const operationRequestId = 'purchase-payment-phase72-paid';
        final approvalId = await approvals.approve(
          accounts: faRepo,
          account: account,
          amountQirsh: 60000,
          operationType: NegativeBalanceOperationType.purchasePayment,
          sourceDocumentId: operationRequestId,
          sourceDocumentType: FinancialAccountEntrySource.purchasePayment.name,
          requesterUserId: 'user-1',
        );

        final intake = await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            createdByUserId: 'user-1',
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            paymentMode: PurchasePaymentMode.paid,
            negativeBalanceApprovalId: approvalId,
            operationRequestId: operationRequestId,
          ),
        );

        expect(intake.financialAccountId, account.id);
        expect(intake.paymentMode, PurchasePaymentMode.paid);

        final balance = await faRepo.currentBalanceForAccount(account.id);
        expect(balance, -60000);

        final statement = await faRepo.statementForAccount(account.id);
        expect(statement.lines.length, 1);
        expect(
          statement.lines.first.entry.sourceType,
          FinancialAccountEntrySource.purchasePayment,
        );
        expect(
          statement.lines.first.entry.direction,
          FinancialAccountEntryDirection.outflow,
        );
        expect(statement.lines.first.entry.amountQirsh, 60000);
        expect(statement.lines.first.entry.paymentMethod, PaymentMethod.cash);
      });

      test('partial purchase creates outflow FA entry for paid portion',
          () async {
        final supplier = (await supplierRepo.listSuppliers()).first;
        final account = (await faRepo.listAccounts()).first;
        const operationRequestId = 'purchase-payment-phase72-partial';
        final approvalId = await approvals.approve(
          accounts: faRepo,
          account: account,
          amountQirsh: 20000,
          operationType: NegativeBalanceOperationType.purchasePayment,
          sourceDocumentId: operationRequestId,
          sourceDocumentType: FinancialAccountEntrySource.purchasePayment.name,
          requesterUserId: 'user-1',
        );

        await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            createdByUserId: 'user-1',
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.bankTransfer,
            paymentMode: PurchasePaymentMode.partial,
            paidAmountQirsh: 20000,
            negativeBalanceApprovalId: approvalId,
            operationRequestId: operationRequestId,
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(account.id);
        expect(balance, -20000);

        final statement = await faRepo.statementForAccount(account.id);
        expect(statement.lines.length, 1);
        expect(statement.lines.first.entry.amountQirsh, 20000);
        expect(
          statement.lines.first.entry.paymentMethod,
          PaymentMethod.bankTransfer,
        );
      });

      test('credit purchase does NOT create FA entry', () async {
        final supplier = (await supplierRepo.listSuppliers()).first;
        final accountId = (await faRepo.listAccounts()).first.id;

        await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            createdByUserId: 'user-1',
            financialAccountId: accountId,
            paymentMode: PurchasePaymentMode.credit,
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });

      test('purchase without financialAccountId does NOT create FA entry',
          () async {
        final supplier = (await supplierRepo.listSuppliers()).first;
        final accountId = (await faRepo.listAccounts()).first.id;

        await purchaseRepo.createPurchaseIntake(
          PurchaseIntakeDraft(
            supplierId: supplier.id,
            productId: product.id,
            quantityKg: 200,
            entryUnit: GrainUnit.kilogram,
            unitPricePiastersPerKg: 300,
            createdByUserId: 'user-1',
            paymentMode: PurchasePaymentMode.paid,
          ),
        );

        final balance = await faRepo.currentBalanceForAccount(accountId);
        expect(balance, 0);
      });
    });

    group('Balance consistency across transaction types', () {
      late LocalFinancialAccountRepository faRepo;

      setUp(() async {
        faRepo = LocalFinancialAccountRepository();
        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'خزينة',
            type: FinancialAccountType.treasury,
            createdByUserId: 'owner',
          ),
        );
      });

      test('multiple inflows accumulate correctly', () async {
        final accountId = (await faRepo.listAccounts()).first.id;

        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'user-1',
        );
        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.customerCollection,
          sourceDocumentId: 'col-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'user-1',
        );

        expect(await faRepo.currentBalanceForAccount(accountId), 15000);
      });

      test('inflows and outflows combine correctly', () async {
        final accountId = (await faRepo.listAccounts()).first.id;

        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 100000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'user-1',
        );
        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 30000,
          sourceType: FinancialAccountEntrySource.expense,
          sourceDocumentId: 'exp-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'user-1',
        );
        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 20000,
          sourceType: FinancialAccountEntrySource.supplierSettlement,
          sourceDocumentId: 'spy-1',
          effectiveDate: DateTime(2026, 1, 3),
          createdByUserId: 'user-1',
        );

        expect(await faRepo.currentBalanceForAccount(accountId), 50000);
      });

      test('cancellation reversal returns balance to zero', () async {
        final accountId = (await faRepo.listAccounts()).first.id;

        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 75000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: 'user-1',
          paymentMethod: PaymentMethod.cash,
        );
        expect(await faRepo.currentBalanceForAccount(accountId), 75000);

        await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 75000,
          sourceType: FinancialAccountEntrySource.cancellationReversal,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: 'user-1',
          reversalOf: 'sale-1',
          paymentMethod: PaymentMethod.cash,
        );
        expect(await faRepo.currentBalanceForAccount(accountId), 0);

        final statement = await faRepo.statementForAccount(accountId);
        expect(statement.lines.length, 2);
        expect(statement.lines.last.entry.reversalOf, 'sale-1');
      });
    });

    group('Direction consistency', () {
      late LocalFinancialAccountRepository faRepo;
      late _ApprovalHarness approvals;

      setUp(() async {
        approvals = _ApprovalHarness();
        faRepo = LocalFinancialAccountRepository(
          negativeBalanceApprovalService: approvals.service,
        );
        await faRepo.createAccount(
          const FinancialAccountDraft(
            name: 'حساب بنكي',
            type: FinancialAccountType.bank,
            allowNegativeBalance: true,
            createdByUserId: 'owner',
          ),
        );
      });

      test('cash received = inflow', () async {
        final accountId = (await faRepo.listAccounts()).first.id;
        final entry = await faRepo.createEntry(
          accountId: accountId,
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdByUserId: 'user-1',
          paymentMethod: PaymentMethod.cash,
        );
        expect(entry.signedAmountQirsh, 10000);
      });

      test('cash paid = outflow', () async {
        final account = (await faRepo.listAccounts()).first;
        final approvalId = await approvals.approve(
          accounts: faRepo,
          account: account,
          amountQirsh: 10000,
          operationType: NegativeBalanceOperationType.supplierPayment,
          sourceDocumentId: 'spy-1',
          sourceDocumentType:
              FinancialAccountEntrySource.supplierSettlement.name,
          requesterUserId: 'user-1',
        );
        final entry = await faRepo.createEntry(
          accountId: account.id,
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 10000,
          sourceType: FinancialAccountEntrySource.supplierSettlement,
          sourceDocumentId: 'spy-1',
          effectiveDate: DateTime(2026),
          createdByUserId: 'user-1',
          paymentMethod: PaymentMethod.bankTransfer,
          negativeBalanceApprovalId: approvalId,
        );
        expect(entry.signedAmountQirsh, -10000);
      });
    });

    group('FinancialAccountEntry model with new fields', () {
      test('entry stores paymentMethod', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
          paymentMethod: PaymentMethod.mobileWallet,
        );
        expect(entry.paymentMethod, PaymentMethod.mobileWallet);
      });

      test('entry allows null paymentMethod', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.inflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.salePayment,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
        );
        expect(entry.paymentMethod, null);
      });

      test('entry stores reversalOf', () {
        final entry = FinancialAccountEntry(
          id: 'fae-1',
          accountId: 'fa-1',
          direction: FinancialAccountEntryDirection.outflow,
          amountQirsh: 5000,
          sourceType: FinancialAccountEntrySource.cancellationReversal,
          sourceDocumentId: 'sale-1',
          effectiveDate: DateTime(2026),
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
          reversalOf: 'sale-original',
        );
        expect(entry.reversalOf, 'sale-original');
      });
    });

    group('SaleRecord model with new fields', () {
      test('stores financialAccountId and paymentMethod', () {
        final record = SaleRecord(
          id: 'sale-1',
          productId: 'p-1',
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          totalQirsh: 50000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.cash,
        );
        expect(record.financialAccountId, 'fa-1');
        expect(record.paymentMethod, PaymentMethod.cash);
      });

      test('copyWith preserves financialAccountId and paymentMethod', () {
        final record = SaleRecord(
          id: 'sale-1',
          productId: 'p-1',
          quantityKg: 100,
          salePriceQirshPerKg: 500,
          totalQirsh: 50000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.bankTransfer,
        );
        final copied = record.copyWith(paidAmountQirsh: 20000);
        expect(copied.financialAccountId, 'fa-1');
        expect(copied.paymentMethod, PaymentMethod.bankTransfer);
      });
    });

    group('PurchaseIntake model with new fields', () {
      test(
          'stores financialAccountId, paymentMethod, paymentMode, paidAmountQirsh',
          () {
        final intake = PurchaseIntake(
          id: 'pin-1',
          supplierId: 's-1',
          productId: 'p-1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 300,
          totalAmountPiasters: 60000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.cash,
          paymentMode: PurchasePaymentMode.partial,
          paidAmountQirsh: 20000,
        );
        expect(intake.financialAccountId, 'fa-1');
        expect(intake.paymentMethod, PaymentMethod.cash);
        expect(intake.paymentMode, PurchasePaymentMode.partial);
        expect(intake.paidAmountQirsh, 20000);
      });

      test('effectivePaidAmountQirsh returns paidAmountQirsh when set', () {
        final intake = PurchaseIntake(
          id: 'pin-1',
          supplierId: 's-1',
          productId: 'p-1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 300,
          totalAmountPiasters: 60000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          paymentMode: PurchasePaymentMode.partial,
          paidAmountQirsh: 25000,
        );
        expect(intake.effectivePaidAmountQirsh, 25000);
      });

      test('effectivePaidAmountQirsh returns total for paid mode', () {
        final intake = PurchaseIntake(
          id: 'pin-1',
          supplierId: 's-1',
          productId: 'p-1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 300,
          totalAmountPiasters: 60000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          paymentMode: PurchasePaymentMode.paid,
        );
        expect(intake.effectivePaidAmountQirsh, 60000);
      });

      test('effectivePaidAmountQirsh returns 0 for credit mode', () {
        final intake = PurchaseIntake(
          id: 'pin-1',
          supplierId: 's-1',
          productId: 'p-1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 300,
          totalAmountPiasters: 60000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          paymentMode: PurchasePaymentMode.credit,
        );
        expect(intake.effectivePaidAmountQirsh, 0);
      });

      test('copyWith preserves financialAccountId and payment fields', () {
        final intake = PurchaseIntake(
          id: 'pin-1',
          supplierId: 's-1',
          productId: 'p-1',
          quantityKg: 200,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 300,
          totalAmountPiasters: 60000,
          createdByUserId: 'user-1',
          createdAt: DateTime(2026),
          stockMovementId: 'sm-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.check,
          paymentMode: PurchasePaymentMode.paid,
          paidAmountQirsh: 60000,
        );
        final copied = intake.copyWith(cancellation: null);
        expect(copied.financialAccountId, 'fa-1');
        expect(copied.paymentMethod, PaymentMethod.check);
        expect(copied.paymentMode, PurchasePaymentMode.paid);
        expect(copied.paidAmountQirsh, 60000);
      });
    });

    group('CustomerCollectionRecord model with new fields', () {
      test('stores financialAccountId and paymentMethod', () {
        final record = CustomerCollectionRecord(
          id: 'col-1',
          customerId: 'c-1',
          date: DateTime(2026),
          amountQirsh: 30000,
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.bankTransfer,
        );
        expect(record.financialAccountId, 'fa-1');
        expect(record.paymentMethod, PaymentMethod.bankTransfer);
      });
    });

    group('SupplierPaymentRecord model with new fields', () {
      test('stores financialAccountId and paymentMethod', () {
        final record = SupplierPaymentRecord(
          id: 'spy-1',
          supplierId: 's-1',
          date: DateTime(2026),
          amountQirsh: 40000,
          createdAt: DateTime(2026),
          createdByUserId: 'user-1',
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.cash,
        );
        expect(record.financialAccountId, 'fa-1');
        expect(record.paymentMethod, PaymentMethod.cash);
      });
    });

    group('ExpenseRecord model with new fields', () {
      test('stores financialAccountId and paymentMethod', () {
        final record = ExpenseRecord(
          id: 'exp-1',
          date: DateTime(2026),
          category: 'مصاريف',
          amountQirsh: 5000,
          createdAt: DateTime(2026),
          financialAccountId: 'fa-1',
          paymentMethod: PaymentMethod.mobileWallet,
        );
        expect(record.financialAccountId, 'fa-1');
        expect(record.paymentMethod, PaymentMethod.mobileWallet);
      });
    });
  });
}

final _approvalOwner = AppUser(
  id: 'phase72-owner',
  name: 'Phase 72 owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _ApprovalHarness {
  _ApprovalHarness()
      : _auth = LocalAuthRepository(
          seedAccounts: [
            LocalAuthAccount(user: _approvalOwner, password: 'owner-password'),
          ],
        ) {
    service = NegativeBalanceApprovalService(
      authRepository: _auth,
      approvalRepository: LocalNegativeBalanceApprovalRepository(),
      auditLogRepository: LocalAuditLogRepository(),
    );
  }

  final LocalAuthRepository _auth;
  late final NegativeBalanceApprovalService service;

  Future<String> approve({
    required FinancialAccountRepository accounts,
    required FinancialAccount account,
    required int amountQirsh,
    required NegativeBalanceOperationType operationType,
    required String sourceDocumentId,
    required String sourceDocumentType,
    required String requesterUserId,
  }) async {
    final balanceBefore = await accounts.currentBalanceForAccount(account.id);
    return service.requestApproval(
      draft: NegativeBalanceApprovalDraft(
        requestedByUserId: requesterUserId,
        approvedByOwnerUserId: _approvalOwner.id,
        accountId: account.id,
        amountQirsh: amountQirsh,
        operationType: operationType,
        sourceDocumentId: sourceDocumentId,
        sourceDocumentType: sourceDocumentType,
        balanceBeforeQirsh: balanceBefore,
        expectedBalanceAfterQirsh: balanceBefore - amountQirsh,
        reason: 'Phase 72 approved negative-balance operation.',
      ),
      ownerPhone: _approvalOwner.phone,
      ownerPassword: 'owner-password',
    );
  }
}
