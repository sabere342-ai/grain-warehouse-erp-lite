import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_controller.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/purchases/purchases_screen.dart';

void main() {
  group('paid purchase financial contract', () {
    test(
        'credit purchase creates stock and supplier debt without cash movement',
        () async {
      final fixture = await _fixture();
      final beforeCash =
          await fixture.accounts.currentBalanceForAccount(fixture.cash.id);

      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.draft(
          requestId: 'credit-1',
          paymentMode: PurchasePaymentMode.credit,
        ),
      );

      expect(purchase.outstandingAmountQirsh, 500);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 5);
      expect(await fixture.ledger.balanceForSupplier(fixture.supplier.id), 500);
      expect(
        await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
        beforeCash,
      );
      expect(
        (await fixture.accounts.statementForAccount(fixture.cash.id)).lines,
        hasLength(1),
      );
    });

    test(
        'fully paid cash purchase leaves no supplier debt and reverses exactly',
        () async {
      final fixture = await _fixture();
      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.draft(
          requestId: 'paid-cash-1',
          paymentMode: PurchasePaymentMode.paid,
          account: fixture.cash,
          method: PaymentMethod.cash,
        ),
      );

      expect(purchase.effectivePaidAmountQirsh, 500);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.ledger.balanceForSupplier(fixture.supplier.id), 0);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          1500);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 5);

      final cancelled = await fixture.purchases.cancelPurchaseIntake(
        purchaseIntakeId: purchase.id,
        cancelledByUserId: 'owner-1',
        cancellationReason: 'إلغاء اختبار',
      );
      expect(cancelled.isCancelled, isTrue);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          2000);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 0);
      expect(await fixture.ledger.listEntries(), isEmpty);
      final accountEntries =
          (await fixture.accounts.statementForAccount(fixture.cash.id))
              .lines
              .map((line) => line.entry)
              .toList(growable: false);
      expect(accountEntries, hasLength(3));
      expect(accountEntries.last.reversalOf, purchase.id);
      expect(accountEntries.last.paymentMethod, PaymentMethod.cash);
    });

    test('bank and wallet purchases debit only their compatible accounts',
        () async {
      final fixture = await _fixture();
      await fixture.purchases.createPurchaseIntake(
        fixture.draft(
          requestId: 'paid-bank-1',
          paymentMode: PurchasePaymentMode.paid,
          account: fixture.bank,
          method: PaymentMethod.bankTransfer,
        ),
      );
      await fixture.purchases.createPurchaseIntake(
        fixture.draft(
          requestId: 'paid-wallet-1',
          paymentMode: PurchasePaymentMode.paid,
          account: fixture.wallet,
          method: PaymentMethod.mobileWallet,
        ),
      );

      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          2000);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.bank.id),
          1500);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.wallet.id),
          1500);
      expect(await fixture.ledger.balanceForSupplier(fixture.supplier.id), 0);
    });

    test('paid route is mandatory, compatible, active, and never cheque',
        () async {
      final fixture = await _fixture();

      Future<void> rejected(PurchaseIntakeDraft draft) async {
        await expectLater(
          fixture.purchases.createPurchaseIntake(draft),
          throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
        );
        expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
        expect(await fixture.inventory.listAllMovements(), isEmpty);
        expect(await fixture.ledger.listEntries(), isEmpty);
      }

      await rejected(fixture.draft(
        requestId: 'missing-method',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.cash,
      ));
      await rejected(fixture.draft(
        requestId: 'missing-account',
        paymentMode: PurchasePaymentMode.paid,
        method: PaymentMethod.cash,
      ));
      await rejected(fixture.draft(
        requestId: 'wrong-type',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.bank,
        method: PaymentMethod.cash,
      ));
      await rejected(fixture.draft(
        requestId: 'cheque',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.cash,
        method: PaymentMethod.check,
      ));

      await fixture.accounts.deactivateAccount(fixture.cash.id, 'owner-1');
      await rejected(fixture.draft(
        requestId: 'inactive',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.cash,
        method: PaymentMethod.cash,
      ));
    });

    test('credit route is rejected instead of retaining hidden payment data',
        () async {
      final fixture = await _fixture();
      await expectLater(
        fixture.purchases.createPurchaseIntake(
          fixture.draft(
            requestId: 'credit-hidden-route',
            paymentMode: PurchasePaymentMode.credit,
            account: fixture.cash,
            method: PaymentMethod.cash,
          ),
        ),
        throwsArgumentError,
      );
      expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
      expect(await fixture.ledger.listEntries(), isEmpty);
    });

    test('same operation request replays once and changed payload is stale',
        () async {
      final fixture = await _fixture();
      final draft = fixture.draft(
        requestId: 'paid-replay-1',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.cash,
        method: PaymentMethod.cash,
      );
      final first = await fixture.purchases.createPurchaseIntake(draft);
      final replay = await fixture.purchases.createPurchaseIntake(draft);

      expect(replay.id, first.id);
      expect(await fixture.purchases.listPurchaseIntakes(), hasLength(1));
      expect(await fixture.inventory.listAllMovements(), hasLength(1));
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          1500);
      await expectLater(
        fixture.purchases.createPurchaseIntake(
          fixture.draft(
            requestId: 'paid-replay-1',
            paymentMode: PurchasePaymentMode.paid,
            account: fixture.cash,
            method: PaymentMethod.cash,
            quantityKg: 6,
          ),
        ),
        throwsStateError,
      );
    });

    test('insufficient purchase mutates nothing until exact approval is used',
        () async {
      final fixture = await _fixture(cashOpeningQirsh: 100);
      await fixture.accounts.updateAccountPolicy(
        accountId: fixture.cash.id,
        allowNegativeBalance: true,
        updatedByUserId: 'owner-1',
      );
      final draft = fixture.draft(
        requestId: 'paid-negative-1',
        paymentMode: PurchasePaymentMode.paid,
        account: fixture.cash,
        method: PaymentMethod.cash,
      );

      await expectLater(
        fixture.purchases.createPurchaseIntake(draft),
        throwsStateError,
      );
      expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          100);

      final approvalId = await fixture.approvalService.requestApproval(
        draft: NegativeBalanceApprovalDraft(
          requestedByUserId: 'owner-1',
          approvedByOwnerUserId: '',
          accountId: fixture.cash.id,
          amountQirsh: 500,
          operationType: NegativeBalanceOperationType.purchasePayment,
          sourceDocumentId: 'paid-negative-1',
          sourceDocumentType: FinancialAccountEntrySource.purchasePayment.name,
          balanceBeforeQirsh: 100,
          expectedBalanceAfterQirsh: -400,
          reason: 'اختبار اعتماد شراء',
        ),
        ownerPhone: '01000000000',
        ownerPassword: 'owner123',
      );
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          100);

      final purchase = await fixture.purchases.createPurchaseIntake(
        fixture.draft(
          requestId: 'paid-negative-1',
          paymentMode: PurchasePaymentMode.paid,
          account: fixture.cash,
          method: PaymentMethod.cash,
          negativeBalanceApprovalId: approvalId,
        ),
      );
      expect(purchase.negativeBalanceApprovalId, approvalId);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          -400);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.inventory.currentStockKg(fixture.product.id), 5);
      expect(
        (await fixture.approvals.findById(approvalId))!.status,
        NegativeBalanceApprovalStatus.consumed,
      );
    });
  });

  group('paid purchase UI', () {
    testWidgets('credit hides route fields and paid shows them without cheque',
        (tester) async {
      final fixture = await _fixture();
      final auth = await _signedInAuth(fixture.authRepository);
      addTearDown(auth.dispose);
      addTearDown(fixture.controller.dispose);
      await tester.pumpWidget(_harness(fixture, auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسجيل استلام حبوب'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('سيُضاف كامل إجمالي الفاتورة'), findsOneWidget);
      expect(
          find.byKey(const Key('purchase-payment-method-field')), findsNothing);
      expect(find.byKey(const Key('purchase-financial-account-field')),
          findsNothing);

      await tester.tap(find.byKey(const Key('purchase-payment-mode-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مدفوع بالكامل').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('لن تبقى مديونية على المورد'), findsOneWidget);
      expect(find.byKey(const Key('purchase-payment-method-field')),
          findsOneWidget);
      expect(find.byKey(const Key('purchase-financial-account-field')),
          findsOneWidget);
      expect(find.text('شيك'), findsNothing);

      await tester.tap(find.byKey(const Key('purchase-payment-mode-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('آجل بالكامل').last);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('purchase-payment-method-field')), findsNothing);
      expect(find.byKey(const Key('purchase-financial-account-field')),
          findsNothing);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('payment method filters accounts and clears incompatible value',
        (tester) async {
      final fixture = await _fixture();
      final auth = await _signedInAuth(fixture.authRepository);
      addTearDown(auth.dispose);
      addTearDown(fixture.controller.dispose);
      await tester.pumpWidget(_harness(fixture, auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل استلام حبوب'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('purchase-payment-mode-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مدفوع بالكامل').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('purchase-payment-method-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('purchase-payment-method-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نقدي').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('purchase-financial-account-field')),
      );
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('purchase-financial-account-field')));
      await tester.pumpAndSettle();
      expect(find.textContaining('خزينة الاختبار'), findsWidgets);
      expect(find.textContaining('بنك الاختبار'), findsNothing);
      await tester.tap(find.textContaining('خزينة الاختبار').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('purchase-account-impact-card')),
          findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('purchase-payment-method-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('purchase-payment-method-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحويل بنكي').last);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('purchase-account-impact-card')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('purchase-financial-account-field')),
      );
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('purchase-financial-account-field')));
      await tester.pumpAndSettle();
      expect(find.textContaining('بنك الاختبار'), findsWidgets);
      expect(find.textContaining('خزينة الاختبار'), findsNothing);
      await tester.tap(find.textContaining('بنك الاختبار').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('insufficient paid form shows approval before any mutation',
        (tester) async {
      final fixture = await _fixture(cashOpeningQirsh: 100);
      await fixture.accounts.updateAccountPolicy(
        accountId: fixture.cash.id,
        allowNegativeBalance: true,
        updatedByUserId: 'owner-1',
      );
      final auth = await _signedInAuth(fixture.authRepository);
      addTearDown(auth.dispose);
      addTearDown(fixture.controller.dispose);
      await tester.pumpWidget(_harness(fixture, auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل استلام حبوب'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'الكمية'), '5');
      await tester.enterText(
        find.widgetWithText(TextField, 'سعر الشراء بالجنيه / كجم'),
        '1',
      );
      await tester.tap(find.byKey(const Key('purchase-payment-mode-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مدفوع بالكامل').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('purchase-payment-method-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('purchase-payment-method-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نقدي').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('purchase-financial-account-field')),
      );
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('purchase-financial-account-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('خزينة الاختبار').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('يلزم اعتماد المالك'), findsOneWidget);
      await tester.ensureVisible(find.text('حفظ الاستلام'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الاستلام'));
      await tester.pumpAndSettle();

      expect(find.text('موافقة المالك مطلوبة'), findsOneWidget);
      expect(find.textContaining('الرصيد الحالي:'), findsOneWidget);
      expect(find.textContaining('المبلغ المطلوب:'), findsOneWidget);
      expect(find.textContaining('الرصيد المتوقع:'), findsOneWidget);
      expect(await fixture.purchases.listPurchaseIntakes(), isEmpty);
      expect(await fixture.inventory.listAllMovements(), isEmpty);
      expect(await fixture.ledger.listEntries(), isEmpty);
      expect(await fixture.accounts.currentBalanceForAccount(fixture.cash.id),
          100);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
    });
  });
}

Future<_Fixture> _fixture({int cashOpeningQirsh = 2000}) async {
  final audit = LocalAuditLogRepository();
  final auth = LocalAuthRepository.demo();
  final approvals = LocalNegativeBalanceApprovalRepository();
  final approvalService = NegativeBalanceApprovalService(
    authRepository: auth,
    approvalRepository: approvals,
    auditLogRepository: audit,
  );
  final accounts = LocalFinancialAccountRepository(
    auditLogRepository: audit,
    negativeBalanceApprovalService: approvalService,
  );
  Future<FinancialAccount> account(
    String name,
    FinancialAccountType type,
    int opening,
  ) async {
    final value = await accounts.createAccount(
      FinancialAccountDraft(
        name: name,
        type: type,
        createdByUserId: 'owner-1',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: value.id,
      amountQirsh: opening,
      effectiveDate: DateTime(2026, 7, 1),
      createdByUserId: 'owner-1',
    );
    return value;
  }

  final cash = await account(
      'خزينة الاختبار', FinancialAccountType.treasury, cashOpeningQirsh);
  final bank = await account('بنك الاختبار', FinancialAccountType.bank, 2000);
  final wallet = await account(
      'محفظة الاختبار', FinancialAccountType.electronicWallet, 2000);
  final suppliers = LocalSupplierRepository();
  final supplier = await suppliers.createSupplier(
    const SupplierDraft(name: 'مورد الاختبار'),
  );
  final products = LocalProductRepository();
  final product = await products.createProduct(
    const ProductDraft(name: 'قمح الاختبار', unit: GrainUnit.kilogram),
  );
  final inventory = LocalInventoryRepository(productRepository: products);
  final ledger = LocalSupplierAccountRepository(
    supplierRepository: suppliers,
    auditLogRepository: audit,
    financialAccountRepository: accounts,
    negativeBalanceApprovalService: approvalService,
  );
  final purchases = LocalPurchaseRepository(
    supplierRepository: suppliers,
    productRepository: products,
    inventoryRepository: inventory,
    supplierAccountRepository: ledger,
    financialAccountRepository: accounts,
    auditLogRepository: audit,
  );
  final controller = PurchaseController(
    purchaseRepository: purchases,
    supplierRepository: suppliers,
    productRepository: products,
  );
  return _Fixture(
    authRepository: auth,
    approvalService: approvalService,
    approvals: approvals,
    accounts: accounts,
    cash: cash,
    bank: bank,
    wallet: wallet,
    suppliers: suppliers,
    supplier: supplier,
    products: products,
    product: product,
    inventory: inventory,
    ledger: ledger,
    purchases: purchases,
    controller: controller,
  );
}

class _Fixture {
  const _Fixture({
    required this.authRepository,
    required this.approvalService,
    required this.approvals,
    required this.accounts,
    required this.cash,
    required this.bank,
    required this.wallet,
    required this.suppliers,
    required this.supplier,
    required this.products,
    required this.product,
    required this.inventory,
    required this.ledger,
    required this.purchases,
    required this.controller,
  });

  final LocalAuthRepository authRepository;
  final NegativeBalanceApprovalService approvalService;
  final LocalNegativeBalanceApprovalRepository approvals;
  final LocalFinancialAccountRepository accounts;
  final FinancialAccount cash;
  final FinancialAccount bank;
  final FinancialAccount wallet;
  final LocalSupplierRepository suppliers;
  final Supplier supplier;
  final LocalProductRepository products;
  final Product product;
  final LocalInventoryRepository inventory;
  final LocalSupplierAccountRepository ledger;
  final LocalPurchaseRepository purchases;
  final PurchaseController controller;

  PurchaseIntakeDraft draft({
    required String requestId,
    required PurchasePaymentMode paymentMode,
    FinancialAccount? account,
    PaymentMethod? method,
    int quantityKg = 5,
    String? negativeBalanceApprovalId,
  }) {
    return PurchaseIntakeDraft(
      supplierId: supplier.id,
      supplierName: supplier.name,
      productId: product.id,
      quantityKg: quantityKg,
      entryUnit: GrainUnit.kilogram,
      unitPricePiastersPerKg: 100,
      createdByUserId: 'owner-1',
      paymentMode: paymentMode,
      paidAmountQirsh:
          paymentMode == PurchasePaymentMode.paid ? quantityKg * 100 : null,
      financialAccountId: account?.id,
      paymentMethod: method,
      negativeBalanceApprovalId: negativeBalanceApprovalId,
      operationRequestId: requestId,
    );
  }
}

Future<AuthController> _signedInAuth(LocalAuthRepository repository) async {
  final controller = AuthController(repository: repository);
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

Widget _harness(_Fixture fixture, AuthController auth) {
  return AuthScope(
    controller: auth,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: PurchasesScreen(
        controller: fixture.controller,
        supplierAccountRepository: fixture.ledger,
        financialAccountRepository: fixture.accounts,
        authRepository: fixture.authRepository,
        negativeBalanceApprovalService: fixture.approvalService,
      ),
    ),
  );
}
