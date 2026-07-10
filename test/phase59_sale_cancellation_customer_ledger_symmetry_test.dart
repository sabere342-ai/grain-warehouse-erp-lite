import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';

void main() {
  group('Phase 59 - sale cancellation customer ledger symmetry', () {
    late _Fixture f;

    setUp(() async {
      f = await _createFixture();
    });

    test('cancelling credit sale reverses customer receivable', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0627\u062e\u062a\u0628\u0627\u0631', isActive: true),
      );

      final created = await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      expect(created, isTrue);

      final entries = await f.ledger.listEntries();
      expect(entries.where((e) => e.sourceDocumentType == 'sale'), hasLength(1));
      final originalEntry = entries.firstWhere((e) => e.sourceDocumentType == 'sale');
      expect(originalEntry.debitAmountQirsh, 50000);
      expect(originalEntry.creditAmountQirsh, 0);
      expect(await f.ledger.balanceForCustomer(customer.id), 50000);
      expect(originalEntry.type, CustomerAccountEntryType.creditSale);

      await f.controller.load(_owner);
      final cancelled = await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u062e\u0637\u0623 \u0641\u064a \u0627\u0644\u0625\u062f\u062e\u0627\u0644',
      );
      expect(cancelled, isTrue);

      final allEntries = await f.ledger.listEntries();
      expect(allEntries.where((e) => e.sourceDocumentType == 'sale'), hasLength(1));
      final reversal = allEntries.firstWhere((e) => e.sourceDocumentType == 'saleCancellation');
      expect(reversal.type, CustomerAccountEntryType.saleCancellation);
      expect(reversal.debitAmountQirsh, 0);
      expect(reversal.creditAmountQirsh, 50000);
      expect(reversal.sourceDocumentId, f.controller.sales.first.id);
      expect(reversal.descriptionAr, contains('\u0625\u0644\u063a\u0627\u0621'));

      expect(await f.ledger.balanceForCustomer(customer.id), 0);
    });

    test('cancelling fully paid cash sale does not create reversal entry', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0646\u0642\u062f\u064a', isActive: true),
      );

      await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 5,
        salePriceQirshPerKg: 4000,
        paymentMode: SalePaymentMode.cash,
        customerId: customer.id,
      );

      expect(await f.ledger.balanceForCustomer(customer.id), 0);

      await f.controller.load(_owner);
      final result = await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u0627\u062e\u062a\u0628\u0627\u0631 \u0625\u0644\u063a\u0627\u0621',
      );
      expect(result, isTrue);

      final entries = await f.ledger.listEntries();
      final cancellations = entries.where((e) => e.sourceDocumentType == 'saleCancellation');
      expect(cancellations, isEmpty);
      expect(await f.ledger.balanceForCustomer(customer.id), 0);
    });

    test('cancelling partial payment sale reverses remaining balance', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u062f\u0641\u0639 \u062c\u0632\u0626\u064a', isActive: true),
      );

      await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 8,
        salePriceQirshPerKg: 6000,
        paymentMode: SalePaymentMode.partial,
        customerId: customer.id,
        paidAmountQirsh: 20000,
      );

      expect(await f.ledger.balanceForCustomer(customer.id), 28000);

      await f.controller.load(_owner);
      await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u0625\u0644\u063a\u0627\u0621 \u062f\u0641\u0639 \u062c\u0632\u0626\u064a',
      );

      expect(await f.ledger.balanceForCustomer(customer.id), 0);
      final entries = await f.ledger.listEntries();
      final reversal = entries.firstWhere((e) => e.sourceDocumentType == 'saleCancellation');
      expect(reversal.creditAmountQirsh, 28000);
    });

    test('double cancellation does not create duplicate reversal entries', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0645\u0632\u062f\u0648\u062c', isActive: true),
      );

      await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      await f.controller.load(_owner);

      await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u0627\u0644\u0645\u0631\u0629 \u0627\u0644\u0623\u0648\u0644\u0649',
      );
      await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u0627\u0644\u0645\u0631\u0629 \u0627\u0644\u062b\u0627\u0646\u064a\u0629',
      );

      final entries = await f.ledger.listEntries();
      final cancellations = entries.where((e) => e.sourceDocumentType == 'saleCancellation');
      expect(cancellations, hasLength(1));
      expect(await f.ledger.balanceForCustomer(customer.id), 0);
    });

    test('reversal entry is linked to original sale via sourceDocumentId', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0627\u0644\u062a\u062d\u0642\u0642', isActive: true),
      );

      await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      await f.controller.load(_owner);
      final saleId = f.controller.sales.first.id;

      await f.controller.cancelSale(
        user: _owner,
        saleId: saleId,
        cancellationReason: '\u062a\u062d\u0642\u0642',
      );

      final reversal = (await f.ledger.listEntries())
          .firstWhere((e) => e.sourceDocumentType == 'saleCancellation');
      expect(reversal.sourceDocumentId, saleId);
    });

    test('cancellation blocked when customer has collections', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0645\u062a\u062d\u0635\u0644', isActive: true),
      );

      await f.controller.createSale(
        user: _owner,
        productId: f.product.id,
        quantityKg: 10,
        salePriceQirshPerKg: 5000,
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      );
      await f.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: customer.id,
          date: DateTime.now(),
          amountQirsh: 10000,
          createdByUserId: _owner.id,
        ),
      );

      expect(await f.ledger.balanceForCustomer(customer.id), 40000);

      await f.controller.load(_owner);
      final result = await f.controller.cancelSale(
        user: _owner,
        saleId: f.controller.sales.first.id,
        cancellationReason: '\u0645\u062d\u0627\u0648\u0644\u0629 \u0625\u0644\u063a\u0627\u0621',
      );
      expect(result, isFalse);
      expect(f.controller.errorMessage, isNotNull);
    });

    test('direct repository reversal mirrors controller behavior', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u0639\u0645\u064a\u0644 \u0645\u0628\u0627\u0634\u0631', isActive: true),
      );

      final sale = await f.sales.createSale(
        SaleDraft(
          productId: f.product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: _owner.id,
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ),
      );
      await f.ledger.createCreditSaleEntry(sale: sale, customerId: customer.id);
      expect(await f.ledger.balanceForCustomer(customer.id), 50000);

      final cancelled = await f.sales.cancelSale(
        saleId: sale.id,
        cancelledByUserId: _owner.id,
        cancellationReason: '\u0625\u0644\u063a\u0627\u0621 \u0645\u0628\u0627\u0634\u0631',
      );
      final reversal = await f.ledger.reverseSaleEntry(
        cancelledSale: cancelled,
        cancelledByUserId: _owner.id,
        cancellationReason: '\u0625\u0644\u063a\u0627\u0621 \u0645\u0628\u0627\u0634\u0631',
      );

      expect(reversal.creditAmountQirsh, 50000);
      expect(await f.ledger.balanceForCustomer(customer.id), 0);
      final logs = await f.audit.listLogs();
      expect(logs.any((e) => e.actionType == 'customer.sale.reversed'), isTrue);
    });

    test('reverseSaleEntry fails for non-existent sale', () async {
      final nonExistentSale = SaleRecord(
        id: 'no-such-sale',
        productId: f.product.id,
        quantityKg: 1,
        salePriceQirshPerKg: 1000,
        totalQirsh: 1000,
        createdByUserId: _owner.id,
        createdAt: DateTime.now(),
        stockMovementId: 'mov-1',
      );

      expect(
        () => f.ledger.reverseSaleEntry(
          cancelledSale: nonExistentSale,
          cancelledByUserId: _owner.id,
          cancellationReason: '\u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f',
        ),
        throwsStateError,
      );
    });

    test('reverseSaleEntry creates audit log entry', () async {
      final customer = await f.customers.createCustomer(
        const CustomerDraft(name: '\u062a\u062f\u0642\u064a\u0642', isActive: true),
      );
      final sale = await f.sales.createSale(
        SaleDraft(
          productId: f.product.id,
          quantityKg: 5,
          salePriceQirshPerKg: 2000,
          createdByUserId: _owner.id,
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ),
      );
      await f.ledger.createCreditSaleEntry(sale: sale, customerId: customer.id);
      await f.ledger.reverseSaleEntry(
        cancelledSale: sale,
        cancelledByUserId: _owner.id,
        cancellationReason: '\u062a\u062f\u0642\u064a\u0642 \u0627\u0644\u062a\u062f\u0642\u064a\u0642',
      );

      final logs = await f.audit.listLogs();
      expect(logs.any((e) => e.actionType == 'customer.sale.reversed'), isTrue);
    });
  });
}

final _owner = AppUser(
  id: 'owner-1',
  name: '\u0645\u0627\u0644\u0643',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _Fixture {
  final LocalProductRepository products = LocalProductRepository();
  late final LocalInventoryRepository inventory;
  final LocalCustomerRepository customers = LocalCustomerRepository(
    auditLogRepository: LocalAuditLogRepository(),
  );
  final LocalAuditLogRepository audit = LocalAuditLogRepository();
  late final LocalSaleRepository sales;
  late final LocalCustomerAccountRepository ledger;
  late final SaleController controller;
  late final Product product;
}

Future<_Fixture> _createFixture() async {
  final f = _Fixture();
  f.inventory = LocalInventoryRepository(productRepository: f.products);
  f.product = await f.products.createProduct(
    const ProductDraft(
      name: '\u062d\u0628\u0648\u0628 \u0627\u062e\u062a\u0628\u0627\u0631',
      unit: GrainUnit.kilogram,
      defaultSalePricePiastersPerKg: 5000,
      referenceCostPricePiastersPerKg: 4000,
    ),
  );
  await f.inventory.createMovement(
    StockMovementDraft(
      productId: f.product.id,
      movementType: StockMovementType.openingBalance,
      quantityKg: 1000,
      createdByUserId: _owner.id,
      note: 'opening',
    ),
  );
  f.sales = LocalSaleRepository(
    productRepository: f.products,
    inventoryRepository: f.inventory,
  );
  f.ledger = LocalCustomerAccountRepository(
    customerRepository: f.customers,
    auditLogRepository: f.audit,
  );
  f.controller = SaleController(
    saleRepository: f.sales,
    productRepository: f.products,
    inventoryRepository: f.inventory,
    customerRepository: f.customers,
    customerAccountRepository: f.ledger,
  );
  return f;
}
