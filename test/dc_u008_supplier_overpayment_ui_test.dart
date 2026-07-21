import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  group('DC-U008 Supplier Overpayment UI', () {
    group('SupplierPaymentDraft overpayment fields', () {
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository repo;
      late LocalFinancialAccountRepository accounts;
      late LocalAuditLogRepository audit;
      late NegativeBalanceApprovalService approvals;
      late FinancialAccount account;
      late Supplier supplier;
      late String ownerId;

      setUp(() async {
        audit = LocalAuditLogRepository();
        final auth = LocalAuthRepository.empty();
        final owner = await auth.createFirstOwner(
          name: 'Owner',
          phone: '01000000001',
          password: 'secret',
        );
        ownerId = owner.id;
        approvals = NegativeBalanceApprovalService(
          authRepository: auth,
          approvalRepository: LocalNegativeBalanceApprovalRepository(),
          auditLogRepository: audit,
        );
        accounts = LocalFinancialAccountRepository(
          auditLogRepository: audit,
          negativeBalanceApprovalService: approvals,
        );
        account = await accounts.createAccount(FinancialAccountDraft(
          name: 'Cash',
          type: FinancialAccountType.treasury,
          createdByUserId: ownerId,
          allowNegativeBalance: true,
        ));
        await accounts.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: ownerId,
        );
        supplierRepo = LocalSupplierRepository();
        supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد تجريبي'),
        );
        repo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          auditLogRepository: audit,
          financialAccountRepository: accounts,
          negativeBalanceApprovalService: approvals,
        );
        await repo.createPurchaseEntry(
            purchase: PurchaseIntake(
          id: 'test-purchase-1',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 100000,
          createdByUserId: ownerId,
          createdAt: DateTime(2026, 7, 1),
          stockMovementId: 'mov-1',
        ));
      });

      test('normal payment with no overpayment succeeds', () async {
        final payment = await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 5000,
          createdByUserId: ownerId,
          financialAccountId: account.id,
          paymentMethod: PaymentMethod.cash,
        ));
        expect(payment.amountQirsh, 5000);
        expect(payment.settledAmountQirsh, 5000);
        expect(payment.advanceAmountQirsh, 0);
        expect(await repo.balanceForSupplier(supplier.id), 95000);
      });

      test('overpayment creates advance with correct breakdown', () async {
        const requestId = 'supplier-overpay-1';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 2000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 10000,
            expectedBalanceAfterQirsh: -92000,
            reason: 'Test overpayment',
          ),
          ownerPhone: '01000000001',
          ownerPassword: 'secret',
        );

        final payment = await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 102000,
          createdByUserId: ownerId,
          financialAccountId: account.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
          negativeBalanceApprovalId: approvalId,
        ));

        expect(payment.amountQirsh, 102000);
        expect(payment.settledAmountQirsh, 100000);
        expect(payment.advanceAmountQirsh, 2000);
        expect(await repo.balanceForSupplier(supplier.id), 0);

        final advances = await repo.listAdvances();
        expect(advances.length, 1);
        expect(advances.single.amountQirsh, 2000);
        expect(await repo.remainingAdvanceQirsh(advances.single.id), 2000);
      });

      test('overpayment without financialAccountId is rejected', () async {
        const requestId = 'supplier-overpay-no-account';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 2000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 10000,
            expectedBalanceAfterQirsh: 8000,
            reason: 'Test',
          ),
          ownerPhone: '01000000001',
          ownerPassword: 'secret',
        );

        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 7, 2),
            amountQirsh: 102000,
            createdByUserId: ownerId,
            paymentMethod: PaymentMethod.cash,
            operationRequestId: requestId,
            overpaymentApprovalId: approvalId,
            negativeBalanceApprovalId: approvalId,
          )),
          throwsA(isA<StateError>()),
        );
      });

      test('overpayment without overpaymentApprovalId is rejected', () async {
        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 7, 2),
            amountQirsh: 102000,
            createdByUserId: ownerId,
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            operationRequestId: 'supplier-overpay-no-approval',
          )),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('requires'),
          )),
        );
      });

      test('replay of same operationRequestId is rejected', () async {
        const requestId = 'supplier-replay-1';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 2000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 10000,
            expectedBalanceAfterQirsh: -92000,
            reason: 'Test replay',
          ),
          ownerPhone: '01000000001',
          ownerPassword: 'secret',
        );

        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 102000,
          createdByUserId: ownerId,
          financialAccountId: account.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
          negativeBalanceApprovalId: approvalId,
        ));

        final approvalId2 = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 2000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: -92000,
            expectedBalanceAfterQirsh: -94000,
            reason: 'Test replay 2',
          ),
          ownerPhone: '01000000001',
          ownerPassword: 'secret',
        );

        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 7, 2),
            amountQirsh: 102000,
            createdByUserId: ownerId,
            financialAccountId: account.id,
            paymentMethod: PaymentMethod.cash,
            operationRequestId: requestId,
            overpaymentApprovalId: approvalId2,
            negativeBalanceApprovalId: approvalId2,
          )),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already processed'),
          )),
        );
      });

      test(
          'overpayment advances and settlements have no partial state on failure',
          () async {
        final balanceBefore = await repo.balanceForSupplier(supplier.id);
        final accountBefore =
            await accounts.currentBalanceForAccount(account.id);

        expect(
          () => repo.createPayment(SupplierPaymentDraft(
            supplierId: supplier.id,
            date: DateTime(2026, 7, 2),
            amountQirsh: 102000,
            createdByUserId: ownerId,
          )),
          throwsA(isA<StateError>()),
        );

        expect(await repo.balanceForSupplier(supplier.id), balanceBefore);
        expect(
          await accounts.currentBalanceForAccount(account.id),
          accountBefore,
        );
        expect((await repo.listAdvances()).length, 0);
      });
    });

    group('SupplierController.recordPayment', () {
      late SupplierController controller;
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository accountRepo;
      late LocalAuditLogRepository audit;
      late LocalAuthRepository auth;
      late NegativeBalanceApprovalService approvals;
      late LocalFinancialAccountRepository accounts;
      late FinancialAccount financialAccount;
      late Supplier supplier;
      late dynamic owner;

      setUp(() async {
        audit = LocalAuditLogRepository();
        auth = LocalAuthRepository.empty();
        owner = await auth.createFirstOwner(
          name: 'Owner',
          phone: '01000000002',
          password: 'secret',
        );
        approvals = NegativeBalanceApprovalService(
          authRepository: auth,
          approvalRepository: LocalNegativeBalanceApprovalRepository(),
          auditLogRepository: audit,
        );
        accounts = LocalFinancialAccountRepository(
          auditLogRepository: audit,
          negativeBalanceApprovalService: approvals,
        );
        financialAccount = await accounts.createAccount(FinancialAccountDraft(
          name: 'Cash',
          type: FinancialAccountType.treasury,
          createdByUserId: owner.id,
          allowNegativeBalance: true,
        ));
        await accounts.setOpeningBalance(
          accountId: financialAccount.id,
          amountQirsh: 10000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        supplierRepo = LocalSupplierRepository();
        supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد'),
        );
        accountRepo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          auditLogRepository: audit,
          financialAccountRepository: accounts,
          negativeBalanceApprovalService: approvals,
        );
        await accountRepo.createPurchaseEntry(
            purchase: PurchaseIntake(
          id: 'ctrl-purchase-1',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 50000,
          createdByUserId: owner.id,
          createdAt: DateTime(2026, 7, 1),
          stockMovementId: 'mov-ctrl-1',
        ));
        controller = SupplierController(
          repository: supplierRepo,
          accountRepository: accountRepo,
        );
      });

      test('recordPayment succeeds for normal payment', () async {
        final result = await controller.recordPayment(
          user: owner,
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 5000,
          notes: 'دفعة نقدية',
          financialAccountId: financialAccount.id,
          paymentMethod: PaymentMethod.cash,
        );
        expect(result, isTrue);
        expect(controller.errorMessage, isNull);
        expect(await accountRepo.balanceForSupplier(supplier.id), 45000);
      });

      test('recordPayment returns false and sets error for unauthorized user',
          () async {
        final employee = AppUser(
          id: 'emp-test',
          name: 'Employee',
          phone: '01000000003',
          role: UserRole.employee,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final result = await controller.recordPayment(
          user: employee,
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 10000,
        );
        expect(result, isFalse);
        expect(controller.errorMessage, isNotNull);
      });

      test('recordPayment with overpayment passes fields through', () async {
        const requestId = 'ctrl-overpay-1';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: owner.id,
            approvedByOwnerUserId: owner.id,
            accountId: financialAccount.id,
            amountQirsh: 5000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 10000,
            expectedBalanceAfterQirsh: -45000,
            reason: 'Test',
          ),
          ownerPhone: '01000000002',
          ownerPassword: 'secret',
        );

        final result = await controller.recordPayment(
          user: owner,
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 55000,
          financialAccountId: financialAccount.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
          negativeBalanceApprovalId: approvalId,
        );

        expect(result, isTrue);
        expect(controller.errorMessage, isNull);
        expect(await accountRepo.balanceForSupplier(supplier.id), 0);

        final advances = await accountRepo.listAdvances();
        expect(advances.length, 1);
        expect(advances.single.amountQirsh, 5000);
      });

      test('recordPayment sets specific error on balance changed', () async {
        final settlementAccount = await accounts.createAccount(
          FinancialAccountDraft(
            name: 'Settlement cash',
            type: FinancialAccountType.treasury,
            createdByUserId: owner.id,
          ),
        );
        await accounts.setOpeningBalance(
          accountId: settlementAccount.id,
          amountQirsh: 50000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: owner.id,
        );
        await accountRepo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 50000,
          createdByUserId: owner.id,
          financialAccountId: settlementAccount.id,
          paymentMethod: PaymentMethod.cash,
        ));

        const requestId = 'ctrl-balance-changed';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: owner.id,
            approvedByOwnerUserId: owner.id,
            accountId: financialAccount.id,
            amountQirsh: 5000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 0,
            expectedBalanceAfterQirsh: -5000,
            reason: 'Test',
          ),
          ownerPhone: '01000000002',
          ownerPassword: 'secret',
        );

        final result = await controller.recordPayment(
          user: owner,
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 55000,
          financialAccountId: financialAccount.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
        );

        expect(result, isFalse);
        expect(controller.errorMessage, contains('الرصيد'));
      });

      test('recordPayment sets error when accountRepository is null', () async {
        final ctrl = SupplierController(repository: supplierRepo);
        final result = await ctrl.recordPayment(
          user: owner,
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 10000,
        );
        expect(result, isFalse);
        expect(ctrl.errorMessage, contains('غير متاح'));
      });

      test('SupplierPaymentDraft includes all overpayment fields', () {
        final draft = SupplierPaymentDraft(
          supplierId: 's1',
          date: DateTime(2026),
          amountQirsh: 10000,
          createdByUserId: 'u1',
          financialAccountId: 'acc1',
          paymentMethod: PaymentMethod.cash,
          operationRequestId: 'req1',
          overpaymentApprovalId: 'app1',
          negativeBalanceApprovalId: 'app1',
        );
        expect(draft.financialAccountId, 'acc1');
        expect(draft.paymentMethod, PaymentMethod.cash);
        expect(draft.operationRequestId, 'req1');
        expect(draft.overpaymentApprovalId, 'app1');
      });

      test('SupplierPaymentRecord carries overpayment split fields', () {
        final record = SupplierPaymentRecord(
          id: 'r1',
          supplierId: 's1',
          date: DateTime(2026),
          amountQirsh: 12000,
          createdAt: DateTime(2026),
          createdByUserId: 'u1',
          settledAmountQirsh: 10000,
          advanceAmountQirsh: 2000,
        );
        expect(record.settledAmountQirsh, 10000);
        expect(record.advanceAmountQirsh, 2000);
        expect(record.amountQirsh, 12000);
      });
    });

    group('Supplier advance lifecycle via overpayment', () {
      late LocalSupplierRepository supplierRepo;
      late LocalSupplierAccountRepository repo;
      late LocalFinancialAccountRepository accounts;
      late LocalAuditLogRepository audit;
      late NegativeBalanceApprovalService approvals;
      late FinancialAccount account;
      late Supplier supplier;
      late String ownerId;

      setUp(() async {
        audit = LocalAuditLogRepository();
        final auth = LocalAuthRepository.empty();
        final owner = await auth.createFirstOwner(
          name: 'Owner',
          phone: '01000000003',
          password: 'secret',
        );
        ownerId = owner.id;
        approvals = NegativeBalanceApprovalService(
          authRepository: auth,
          approvalRepository: LocalNegativeBalanceApprovalRepository(),
          auditLogRepository: audit,
        );
        accounts = LocalFinancialAccountRepository(
          auditLogRepository: audit,
          negativeBalanceApprovalService: approvals,
        );
        account = await accounts.createAccount(FinancialAccountDraft(
          name: 'Cash',
          type: FinancialAccountType.treasury,
          createdByUserId: ownerId,
          allowNegativeBalance: true,
        ));
        await accounts.setOpeningBalance(
          accountId: account.id,
          amountQirsh: 20000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: ownerId,
        );
        supplierRepo = LocalSupplierRepository();
        supplier = await supplierRepo.createSupplier(
          const SupplierDraft(name: 'مورد متقدم'),
        );
        repo = LocalSupplierAccountRepository(
          supplierRepository: supplierRepo,
          auditLogRepository: audit,
          financialAccountRepository: accounts,
          negativeBalanceApprovalService: approvals,
        );
        await repo.createPurchaseEntry(
            purchase: PurchaseIntake(
          id: 'adv-purchase-1',
          supplierId: supplier.id,
          productId: 'prod-1',
          quantityKg: 100,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 1000,
          totalAmountPiasters: 100000,
          createdByUserId: ownerId,
          createdAt: DateTime(2026, 7, 1),
          stockMovementId: 'mov-adv-1',
        ));
      });

      test('overpayment creates advance that can be applied to purchase',
          () async {
        const requestId = 'adv-overpay-1';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 3000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 20000,
            expectedBalanceAfterQirsh: -83000,
            reason: 'Advance for future purchases',
          ),
          ownerPhone: '01000000003',
          ownerPassword: 'secret',
        );

        final payment = await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 103000,
          createdByUserId: ownerId,
          financialAccountId: account.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
          negativeBalanceApprovalId: approvalId,
        ));

        expect(payment.settledAmountQirsh, 100000);
        expect(payment.advanceAmountQirsh, 3000);
        expect(await repo.balanceForSupplier(supplier.id), 0);

        final advance = (await repo.listAdvances()).single;
        expect(await repo.remainingAdvanceQirsh(advance.id), 3000);

        await repo.createPurchaseEntry(
            purchase: PurchaseIntake(
          id: 'adv-purchase-2',
          supplierId: supplier.id,
          productId: 'prod-2',
          quantityKg: 50,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 200,
          totalAmountPiasters: 10000,
          createdByUserId: ownerId,
          createdAt: DateTime(2026, 7, 3),
          stockMovementId: 'mov-adv-2',
        ));
        expect(await repo.balanceForSupplier(supplier.id), 10000);

        final application = await repo.applyAdvance(
          SupplierAdvanceApplicationDraft(
            advanceId: advance.id,
            supplierId: supplier.id,
            amountQirsh: 3000,
            date: DateTime(2026, 7, 3),
            createdByUserId: ownerId,
            operationRequestId: 'adv-apply-1',
          ),
        );

        expect(application.amountQirsh, 3000);
        expect(await repo.remainingAdvanceQirsh(advance.id), 0);
        expect(await repo.balanceForSupplier(supplier.id), 7000);
      });

      test('overpayment with zero balance creates advance only', () async {
        final settlementAccount = await accounts.createAccount(
          FinancialAccountDraft(
            name: 'Settlement cash',
            type: FinancialAccountType.treasury,
            createdByUserId: ownerId,
          ),
        );
        await accounts.setOpeningBalance(
          accountId: settlementAccount.id,
          amountQirsh: 100000,
          effectiveDate: DateTime(2026, 1, 1),
          createdByUserId: ownerId,
        );
        await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 2),
          amountQirsh: 100000,
          createdByUserId: ownerId,
          financialAccountId: settlementAccount.id,
          paymentMethod: PaymentMethod.cash,
        ));
        expect(await repo.balanceForSupplier(supplier.id), 0);

        const requestId = 'adv-overpay-zero';
        final approvalId = await approvals.requestApproval(
          draft: NegativeBalanceApprovalDraft(
            requestedByUserId: ownerId,
            approvedByOwnerUserId: ownerId,
            accountId: account.id,
            amountQirsh: 5000,
            operationType: NegativeBalanceOperationType.supplierOverpayment,
            sourceDocumentId: requestId,
            sourceDocumentType: 'supplierOverpayment',
            balanceBeforeQirsh: 20000,
            expectedBalanceAfterQirsh: 15000,
            reason: 'Advance on zero balance',
          ),
          ownerPhone: '01000000003',
          ownerPassword: 'secret',
        );

        final payment2 = await repo.createPayment(SupplierPaymentDraft(
          supplierId: supplier.id,
          date: DateTime(2026, 7, 3),
          amountQirsh: 5000,
          createdByUserId: ownerId,
          financialAccountId: account.id,
          paymentMethod: PaymentMethod.cash,
          operationRequestId: requestId,
          overpaymentApprovalId: approvalId,
          negativeBalanceApprovalId: approvalId,
        ));

        expect(payment2.settledAmountQirsh, 0);
        expect(payment2.advanceAmountQirsh, 5000);
        expect(await repo.balanceForSupplier(supplier.id), 0);

        final advances = await repo.listAdvances();
        expect(advances.length, 1);
        expect(advances.single.amountQirsh, 5000);
      });
    });
  });
}
