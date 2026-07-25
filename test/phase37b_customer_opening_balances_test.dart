import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';

final _now = DateTime(2026, 7, 8);

void main() {
  group('Phase 37B - Customer opening balances', () {
    group('Repository opening balance entry', () {
      late LocalCustomerRepository customers;
      late LocalCustomerAccountRepository repo;

      setUp(() async {
        customers = LocalCustomerRepository();
        repo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
      });

      test('creates opening balance and increases balance', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل', isActive: true),
        );

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 300000,
          createdByUserId: 'owner-1',
        );

        expect(await repo.balanceForCustomer(customer.id), 300000);

        final entries = await repo.listEntries();
        expect(entries.length, 1);
        expect(entries.first.type, CustomerAccountEntryType.openingBalance);
        expect(entries.first.debitAmountQirsh, 300000);
        expect(entries.first.creditAmountQirsh, 0);
        expect(entries.first.sourceDocumentType, 'customerOpeningBalance');
      });

      test('duplicate opening balance is rejected', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 2', isActive: true),
        );

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 300000,
          createdByUserId: 'owner-1',
        );

        expect(
          repo.createOpeningBalanceEntry(
            customerId: customer.id,
            amountQirsh: 100000,
            createdByUserId: 'owner-1',
          ),
          throwsStateError,
        );

        expect(await repo.balanceForCustomer(customer.id), 300000);
      });

      test('hasOpeningBalanceEntry returns correct status', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 3', isActive: true),
        );
        final other = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 4', isActive: true),
        );

        expect(await repo.hasOpeningBalanceEntry(customer.id), isFalse);

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 150000,
          createdByUserId: 'owner-1',
        );

        expect(await repo.hasOpeningBalanceEntry(customer.id), isTrue);
        expect(await repo.hasOpeningBalanceEntry(other.id), isFalse);
      });

      test('negative amount is rejected', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 5', isActive: true),
        );

        expect(
          repo.createOpeningBalanceEntry(
            customerId: customer.id,
            amountQirsh: -50,
            createdByUserId: 'owner-1',
          ),
          throwsArgumentError,
        );
      });

      test('zero amount is rejected', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 6', isActive: true),
        );

        expect(
          repo.createOpeningBalanceEntry(
            customerId: customer.id,
            amountQirsh: 0,
            createdByUserId: 'owner-1',
          ),
          throwsArgumentError,
        );
      });

      test('statement shows opening balance entry with running balance',
          () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 7', isActive: true),
        );

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 500000,
          createdByUserId: 'owner-1',
        );

        final statement = await repo.statementForCustomer(customer.id);
        expect(statement.lines.length, 1);
        expect(statement.lines.first.entry.type,
            CustomerAccountEntryType.openingBalance);
        expect(statement.lines.first.entry.descriptionAr,
            contains('رصيد افتتاحي للعميل'));
        expect(statement.lines.first.runningBalanceQirsh, 500000);
        expect(statement.finalBalanceQirsh, 500000);
      });

      test('opening balance combines with credit sale in statement', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 8', isActive: true),
        );

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 200000,
          createdByUserId: 'owner-1',
        );

        final sale = SaleRecord(
          id: 'sale-ob-1',
          productId: 'prod-ob-1',
          quantityKg: 25,
          salePriceQirshPerKg: 8000,
          totalQirsh: 200000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-ob-1',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        );
        await repo.createCreditSaleEntry(
          sale: sale,
          customerId: customer.id,
        );

        final statement = await repo.statementForCustomer(customer.id);
        expect(statement.lines.length, 2);
        expect(statement.lines[0].entry.type,
            CustomerAccountEntryType.openingBalance);
        expect(statement.lines[0].runningBalanceQirsh, 200000);
        expect(
            statement.lines[1].entry.type, CustomerAccountEntryType.creditSale);
        expect(statement.lines[1].runningBalanceQirsh, 400000);
        expect(statement.finalBalanceQirsh, 400000);
      });

      test('collection reduces opening balance correctly', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 9', isActive: true),
        );

        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 1000000,
          createdByUserId: 'owner-1',
        );

        await repo.createCollection(
          CustomerCollectionDraft(
            customerId: customer.id,
            date: DateTime.now(),
            amountQirsh: 400000,
            createdByUserId: 'owner-1',
          ),
        );

        final statement = await repo.statementForCustomer(customer.id);
        expect(statement.lines.length, 2);
        expect(statement.lines[0].runningBalanceQirsh, 1000000);
        expect(statement.lines[1].runningBalanceQirsh, 600000);
        expect(statement.finalBalanceQirsh, 600000);
      });

      test('opening balance rejected after existing transactions', () async {
        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل 10', isActive: true),
        );

        final sale = SaleRecord(
          id: 'sale-ob-reject',
          productId: 'prod-ob-reject',
          quantityKg: 10,
          salePriceQirshPerKg: 5000,
          totalQirsh: 50000,
          createdByUserId: 'owner-1',
          createdAt: DateTime.now(),
          stockMovementId: 'mov-ob-reject',
          paymentMode: SalePaymentMode.credit,
          customerId: customer.id,
        );
        await repo.createCreditSaleEntry(
          sale: sale,
          customerId: customer.id,
        );

        expect(
          repo.createOpeningBalanceEntry(
            customerId: customer.id,
            amountQirsh: 200000,
            createdByUserId: 'owner-1',
          ),
          throwsStateError,
        );
      });
    });

    group('Controller recordOpeningBalance', () {
      test('returns true and updates state on success', () async {
        final customers = LocalCustomerRepository();
        final repo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final controller = CustomerController(
          repository: customers,
          accountRepository: repo,
        );

        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل', isActive: true),
        );
        final owner = AppUser(
          id: 'owner-1',
          name: 'المالك',
          phone: '01000000000',
          role: UserRole.owner,
          isActive: true,
          createdAt: _now,
          updatedAt: _now,
        );
        await controller.loadCustomers(owner);

        expect(controller.hasOpeningBalanceForCustomer(customer.id), isFalse);

        final success = await controller.recordOpeningBalance(
          user: owner,
          customerId: customer.id,
          amountQirsh: 750000,
        );

        expect(success, isTrue);
        expect(controller.errorMessage, isNull);
        expect(controller.hasOpeningBalanceForCustomer(customer.id), isTrue);
        expect(controller.balanceForCustomer(customer.id), 750000);
      });

      test('returns false on duplicate opening balance', () async {
        final customers = LocalCustomerRepository();
        final repo = LocalCustomerAccountRepository(
          customerRepository: customers,
        );
        final controller = CustomerController(
          repository: customers,
          accountRepository: repo,
        );

        final customer = await customers.createCustomer(
          const CustomerDraft(name: 'عميل', isActive: true),
        );
        await repo.createOpeningBalanceEntry(
          customerId: customer.id,
          amountQirsh: 300000,
          createdByUserId: 'owner-1',
        );
        final owner = AppUser(
          id: 'owner-1',
          name: 'المالك',
          phone: '01000000000',
          role: UserRole.owner,
          isActive: true,
          createdAt: _now,
          updatedAt: _now,
        );
        await controller.loadCustomers(owner);

        final success = await controller.recordOpeningBalance(
          user: owner,
          customerId: customer.id,
          amountQirsh: 50000,
        );

        expect(success, isFalse);
        expect(controller.errorMessage, isNotNull);
      });
    });
  });
}
