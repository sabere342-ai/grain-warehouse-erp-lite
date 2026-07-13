import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  test('supplier payment is atomic and request ids are single-use', () async {
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Supplier A'),
    );
    final audit = LocalAuditLogRepository();
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: audit,
    );
    final cash = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Cash',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: cash.id,
      amountQirsh: 1000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: 'owner',
    );
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    await ledger.createOpeningBalanceEntry(
      supplierId: supplier.id,
      amountQirsh: 500,
      createdByUserId: 'owner',
    );

    final draft = SupplierPaymentDraft(
      supplierId: supplier.id,
      date: DateTime(2026, 1, 2),
      amountQirsh: 100,
      createdByUserId: 'cashier',
      financialAccountId: cash.id,
      operationRequestId: 'pay-1',
    );
    await ledger.createPayment(draft);
    expect((await ledger.listPayments()), hasLength(1));
    expect(await ledger.balanceForSupplier(supplier.id), 400);
    expect(await accounts.currentBalanceForAccount(cash.id), 900);
    await expectLater(ledger.createPayment(draft), throwsA(isA<StateError>()));
    expect((await ledger.listPayments()), hasLength(1));

    final concurrentDraft = SupplierPaymentDraft(
      supplierId: supplier.id,
      date: DateTime(2026, 1, 3),
      amountQirsh: 50,
      createdByUserId: 'cashier',
      financialAccountId: cash.id,
      operationRequestId: 'pay-concurrent',
    );
    Future<Object?> guarded(Future<Object?> future) async {
      try {
        return await future;
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait<Object?>([
      guarded(ledger.createPayment(concurrentDraft)),
      guarded(ledger.createPayment(concurrentDraft)),
    ]);
    expect(results.whereType<SupplierPaymentRecord>(), hasLength(1));
    expect((await ledger.listPayments()), hasLength(2));
  });

  test('purchase rolls back inventory, supplier, financial and audit state',
      () async {
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Supplier B'),
    );
    final products = LocalProductRepository();
    final product = await products.createProduct(
      const ProductDraft(name: 'Grain', unit: GrainUnit.kilogram),
    );
    final failingAudit = _FailOnActionAudit('purchase.created');
    final accounts = LocalFinancialAccountRepository(
      auditLogRepository: failingAudit,
    );
    final cash = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Cash',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: cash.id,
      amountQirsh: 1000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: 'owner',
    );
    final inventory = LocalInventoryRepository(productRepository: products);
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: failingAudit,
      financialAccountRepository: accounts,
    );
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      supplierAccountRepository: ledger,
      financialAccountRepository: accounts,
      auditLogRepository: failingAudit,
    );

    await expectLater(
      purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 10,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 10,
          createdByUserId: 'cashier',
          paymentMode: PurchasePaymentMode.paid,
          financialAccountId: cash.id,
          operationRequestId: 'purchase-1',
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(await purchases.listPurchaseIntakes(), isEmpty);
    expect(await inventory.listAllMovements(), isEmpty);
    expect(await ledger.listEntries(), isEmpty);
    expect(await accounts.currentBalanceForAccount(cash.id), 1000);
  });

  test('purchase modes debit only the effective paid amount', () async {
    final suppliers = LocalSupplierRepository();
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Supplier C'),
    );
    final products = LocalProductRepository();
    final product = await products.createProduct(
      const ProductDraft(name: 'Grain C', unit: GrainUnit.kilogram),
    );
    final audit = LocalAuditLogRepository();
    final accounts = LocalFinancialAccountRepository(auditLogRepository: audit);
    final cash = await accounts.createAccount(
      const FinancialAccountDraft(
        name: 'Cash C',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await accounts.setOpeningBalance(
      accountId: cash.id,
      amountQirsh: 1000,
      effectiveDate: DateTime(2026, 1, 1),
      createdByUserId: 'owner',
    );
    final inventory = LocalInventoryRepository(productRepository: products);
    final ledger = LocalSupplierAccountRepository(
      supplierRepository: suppliers,
      auditLogRepository: audit,
      financialAccountRepository: accounts,
    );
    final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      supplierAccountRepository: ledger,
      financialAccountRepository: accounts,
      auditLogRepository: audit,
    );

    Future<PurchaseIntake> create(PurchasePaymentMode mode, String request,
        [int? paid]) {
      return purchases.createPurchaseIntake(
        PurchaseIntakeDraft(
          supplierId: supplier.id,
          productId: product.id,
          quantityKg: 10,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 10,
          createdByUserId: 'cashier',
          paymentMode: mode,
          paidAmountQirsh: paid,
          financialAccountId: cash.id,
          operationRequestId: request,
        ),
      );
    }

    await create(PurchasePaymentMode.paid, 'purchase-paid');
    await create(PurchasePaymentMode.partial, 'purchase-partial', 30);
    await create(PurchasePaymentMode.credit, 'purchase-credit');
    expect(await accounts.currentBalanceForAccount(cash.id), 870);
  });
}

class _FailOnActionAudit extends LocalAuditLogRepository {
  _FailOnActionAudit(this.actionToFail);

  final String actionToFail;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    if (draft.actionType == actionToFail) {
      throw StateError('Injected audit failure.');
    }
    return super.record(draft);
  }
}
