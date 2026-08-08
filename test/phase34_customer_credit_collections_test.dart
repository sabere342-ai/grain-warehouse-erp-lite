import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

void main() {
  group('Phase 34 customer credit and collections', () {
    test('credit sale creates customer ledger debit and balance', () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.customers.createCustomer(
        const CustomerDraft(name: 'عميل 1', isActive: true),
      );

      final sale = await fixture.sales.createSale(
        SaleDraft(
          productId: fixture.product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: 'user-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ),
      );
      final entry = await fixture.ledger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );

      expect(entry.debitAmountQirsh, sale.totalQirsh);
      expect(await fixture.ledger.balanceForCustomer(customer.id),
          sale.totalQirsh);
    });

    test(
        'invalid credit sale below minimum price does not mutate stock or ledger',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct(
        defaultSalePricePiastersPerKg: 7000,
        minimumSalePricePiastersPerKg: 6000,
      );
      final customer = await fixture.customers.createCustomer(
        const CustomerDraft(name: 'عميل 2', isActive: true),
      );

      expect(
        () => fixture.sales.createSale(
          SaleDraft(
            productId: fixture.product.id,
            quantityKg: 10,
            salePriceQirshPerKg: 5000,
            createdByUserId: 'user-1',
            paymentMode: SalePaymentMode.credit,
            customerId: customer.id,
          ),
        ),
        throwsA(isA<MinimumSalePriceViolation>()),
      );

      expect(await fixture.inventory.currentStockKg(fixture.product.id), 100);
      expect(await fixture.ledger.balanceForCustomer(customer.id), 0);
    });

    test('collection reduces balance and creates audit log', () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.customers.createCustomer(
        const CustomerDraft(name: 'عميل 3', isActive: true),
      );
      final sale = await fixture.sales.createSale(
        SaleDraft(
          productId: fixture.product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: 'user-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ),
      );
      await fixture.ledger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );

      final collection = await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: customer.id,
          date: DateTime(2026, 7, 7),
          amountQirsh: 2000,
          createdByUserId: 'user-1',
        ),
      );

      expect(await fixture.ledger.balanceForCustomer(customer.id), 48000);
      expect(collection.amountQirsh, 2000);
      final logs = await fixture.audit.exportStoredAuditLogs();
      expect(
          logs.any(
              (entry) => entry.actionType == 'customer.collection.recorded'),
          isTrue);
    });

    test('statement shows debit then collection credit with running balance',
        () async {
      final fixture = _Fixture();
      await fixture.seedProduct();
      final customer = await fixture.customers.createCustomer(
        const CustomerDraft(name: 'عميل 4', isActive: true),
      );
      final sale = await fixture.sales.createSale(
        SaleDraft(
          productId: fixture.product.id,
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          createdByUserId: 'user-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        ),
      );
      await fixture.ledger.createCreditSaleEntry(
        sale: sale,
        customerId: customer.id,
      );
      await fixture.ledger.createCollection(
        CustomerCollectionDraft(
          customerId: customer.id,
          date: DateTime(2026, 7, 7),
          amountQirsh: 2000,
          createdByUserId: 'user-1',
        ),
      );

      final statement = await fixture.ledger.statementForCustomer(customer.id);
      expect(statement.lines.length, 2);
      expect(statement.lines.first.runningBalanceQirsh, 50000);
      expect(statement.lines.last.runningBalanceQirsh, 48000);
      expect(statement.finalBalanceQirsh, 48000);
    });
  });
}

class _Fixture {
  _Fixture()
      : customers = LocalCustomerRepository(
          auditLogRepository: LocalAuditLogRepository(),
        ),
        audit = LocalAuditLogRepository() {
    inventory = LocalInventoryRepository(productRepository: products);
  }

  final LocalProductRepository products = LocalProductRepository();
  late LocalInventoryRepository inventory;
  final LocalCustomerRepository customers;
  final LocalAuditLogRepository audit;
  late LocalSaleRepository sales;
  late LocalCustomerAccountRepository ledger;
  late Product product;

  Future<void> seedProduct({
    int? defaultSalePricePiastersPerKg,
    int? minimumSalePricePiastersPerKg,
  }) async {
    final created = await products.createProduct(
      ProductDraft(
        name: 'حبوب 1',
        unit: GrainUnit.kilogram,
        defaultSalePricePiastersPerKg: defaultSalePricePiastersPerKg ?? 5000,
        minimumSalePricePiastersPerKg: minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg: 4000,
      ),
    );
    await inventory.createMovement(
      StockMovementDraft(
        productId: created.id,
        movementType: StockMovementType.openingBalance,
        quantityKg: 100,
        createdByUserId: 'user-1',
        note: 'opening',
      ),
    );
    product = created;
    sales = LocalSaleRepository(
      productCatalogReadRepository:
          ProductCatalogReadRepositoryTestAdapter(products),
      inventoryRepository: inventory,
    );
    ledger = LocalCustomerAccountRepository(
      customerRepository: customers,
      auditLogRepository: audit,
    );
  }
}
