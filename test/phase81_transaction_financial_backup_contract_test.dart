import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

void main() {
  test('v6 export writes financial linkage for all five transaction types',
      () async {
    final source = await _Fixture.seeded();
    final backup = await source.exportService.createBackup();
    final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;

    expect((decoded['metadata'] as Map<String, Object?>)['backupVersion'], 6);
    _expectLink(data, 'sales', PaymentMethod.cash);
    _expectLink(data, 'purchases', PaymentMethod.bankTransfer);
    _expectLink(data, 'customerCollections', PaymentMethod.mobileWallet);
    _expectLink(data, 'supplierPayments', PaymentMethod.check);
    _expectLink(data, 'expenses', PaymentMethod.cash);
  });

  test('v6 service round trip preserves linkage for all five types', () async {
    final source = await _Fixture.seeded();
    final target = await _Fixture.empty();
    final beforeBalance =
        await source.financialAccounts.currentBalanceForAccount(_account.id);
    final beforeStock = await source.inventory.currentStockKg(_product.id);

    final result = await target.restoreService.restoreToEmpty(
      user: _owner,
      jsonText: (await source.exportService.createBackup()).jsonText,
    );

    expect(result.success, isTrue);
    _expectModelLink(
        (await target.sales.listSales()).single, PaymentMethod.cash);
    _expectModelLink((await target.purchases.listPurchaseIntakes()).single,
        PaymentMethod.bankTransfer);
    _expectModelLink((await target.customerAccounts.listCollections()).single,
        PaymentMethod.mobileWallet);
    _expectModelLink((await target.supplierAccounts.listPayments()).single,
        PaymentMethod.check);
    _expectModelLink(
        (await target.expenses.listExpenses()).single, PaymentMethod.cash);
    expect(await target.financialAccounts.currentBalanceForAccount(_account.id),
        beforeBalance);
    expect(await target.inventory.currentStockKg(_product.id), beforeStock);
  });

  test('v5 without linkage restores nulls without invented values', () async {
    final source = await _Fixture.seeded();
    final target = await _Fixture.empty();
    final decoded =
        jsonDecode((await source.exportService.createBackup()).jsonText)
            as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;
    for (final key in const [
      'sales',
      'purchases',
      'customerCollections',
      'supplierPayments',
      'expenses'
    ]) {
      final record =
          (data[key] as List<Object?>).single as Map<String, Object?>;
      record.remove('financialAccountId');
      record.remove('paymentMethod');
    }
    (decoded['metadata'] as Map<String, Object?>)['backupVersion'] = 5;

    final result = await target.restoreService
        .restoreToEmpty(user: _owner, jsonText: _withChecksum(decoded));

    expect(result.success, isTrue);
    _expectNullLink((await target.sales.listSales()).single);
    _expectNullLink((await target.purchases.listPurchaseIntakes()).single);
    _expectNullLink((await target.customerAccounts.listCollections()).single);
    _expectNullLink((await target.supplierAccounts.listPayments()).single);
    _expectNullLink((await target.expenses.listExpenses()).single);
  });

  test('corrupt transaction account reference is rejected before writes',
      () async {
    final source = await _Fixture.seeded();
    final target = await _Fixture.empty();
    final decoded =
        jsonDecode((await source.exportService.createBackup()).jsonText)
            as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;
    ((data['expenses'] as List<Object?>).single
        as Map<String, Object?>)['financialAccountId'] = 'missing-account';

    final result = await target.restoreService
        .restoreToEmpty(user: _owner, jsonText: _withChecksum(decoded));

    expect(result.success, isFalse);
    expect(await target.products.listProducts(), isEmpty);
    expect(await target.sales.listSales(), isEmpty);
    expect(await target.financialAccounts.listAccounts(), isEmpty);
  });

  test('all v1 through v5 remain accepted by preview', () async {
    final source = await _Fixture.seeded();
    final decoded =
        jsonDecode((await source.exportService.createBackup()).jsonText)
            as Map<String, Object?>;
    for (var version = 1; version <= 5; version++) {
      (decoded['metadata'] as Map<String, Object?>)['backupVersion'] = version;
      final target = await _Fixture.empty();
      final result = await target.restoreService
          .restoreToEmpty(user: _owner, jsonText: _withChecksum(decoded));
      expect(result.success, isTrue, reason: 'backup v$version');
    }
  });
}

void _expectLink(Map<String, Object?> data, String key, PaymentMethod method) {
  final value = (data[key] as List<Object?>).single as Map<String, Object?>;
  expect(value['financialAccountId'], _account.id);
  expect(value['paymentMethod'], method.name);
}

void _expectModelLink(dynamic value, PaymentMethod method) {
  expect(value.financialAccountId, _account.id);
  expect(value.paymentMethod, method);
}

void _expectNullLink(dynamic value) {
  expect(value.financialAccountId, isNull);
  expect(value.paymentMethod, isNull);
}

String _withChecksum(Map<String, Object?> decoded) {
  decoded.remove('checksum');
  decoded.remove('checksumNote');
  final body = const JsonEncoder.withIndent('  ').convert(decoded);
  decoded['checksum'] = _adler32(body);
  decoded['checksumNote'] = 'test';
  return const JsonEncoder.withIndent('  ').convert(decoded);
}

String _adler32(String input) {
  const modulus = 65521;
  var a = 1;
  var b = 0;
  for (final byte in utf8.encode(input)) {
    a = (a + byte) % modulus;
    b = (b + a) % modulus;
  }
  return ((b << 16) | a).toRadixString(16).padLeft(8, '0');
}

final _now = DateTime.utc(2026, 7, 11);
final _owner = AppUser(
    id: 'owner',
    name: 'Owner',
    phone: '01000000000',
    role: UserRole.owner,
    isActive: true,
    createdAt: _now,
    updatedAt: _now);
final _product = Product(
    id: 'product-1',
    name: 'Wheat',
    unit: GrainUnit.kilogram,
    isActive: true,
    createdAt: _now,
    updatedAt: _now);
final _supplier = Supplier(
    id: 'supplier-1',
    name: 'Supplier',
    isActive: true,
    createdAt: _now,
    updatedAt: _now);
final _customer = Customer(
    id: 'customer-1',
    name: 'Customer',
    isActive: true,
    createdAt: _now,
    updatedAt: _now);
final _account = FinancialAccount(
    id: 'account-1',
    name: 'Treasury',
    type: FinancialAccountType.treasury,
    createdByUserId: _owner.id,
    createdAt: _now);

class _Fixture {
  _Fixture._({
    required this.products,
    required this.suppliers,
    required this.customers,
    required this.inventory,
    required this.purchases,
    required this.sales,
    required this.customerAccounts,
    required this.supplierAccounts,
    required this.expenses,
    required this.financialAccounts,
    required this.history,
    required this.audit,
  });

  final LocalProductRepository products;
  final LocalSupplierRepository suppliers;
  final LocalCustomerRepository customers;
  final LocalInventoryRepository inventory;
  final LocalPurchaseRepository purchases;
  final LocalSaleRepository sales;
  final LocalCustomerAccountRepository customerAccounts;
  final LocalSupplierAccountRepository supplierAccounts;
  final LocalExpenseRepository expenses;
  final LocalFinancialAccountRepository financialAccounts;
  final LocalDocumentHistoryRepository history;
  final LocalAuditLogRepository audit;

  static Future<_Fixture> empty() async {
    final products = LocalProductRepository();
    final suppliers = LocalSupplierRepository();
    final customers = LocalCustomerRepository();
    final inventory = LocalInventoryRepository(productRepository: products);
    final financialAccounts = LocalFinancialAccountRepository();
    final customerAccounts = LocalCustomerAccountRepository(
        customerRepository: customers,
        financialAccountRepository: financialAccounts);
    final supplierAccounts = LocalSupplierAccountRepository(
        supplierRepository: suppliers,
        financialAccountRepository: financialAccounts);
    final expenses =
        LocalExpenseRepository(financialAccountRepository: financialAccounts);
    final purchases = LocalPurchaseRepository(
        supplierRepository: suppliers,
        productRepository: products,
        inventoryRepository: inventory,
        supplierAccountRepository: supplierAccounts,
        financialAccountRepository: financialAccounts);
    final sales = LocalSaleRepository(
        productRepository: products, inventoryRepository: inventory);
    final history = LocalDocumentHistoryRepository(
        purchaseRepository: purchases,
        saleRepository: sales,
        productRepository: products,
        inventoryRepository: inventory);
    return _Fixture._(
        products: products,
        suppliers: suppliers,
        customers: customers,
        inventory: inventory,
        purchases: purchases,
        sales: sales,
        customerAccounts: customerAccounts,
        supplierAccounts: supplierAccounts,
        expenses: expenses,
        financialAccounts: financialAccounts,
        history: history,
        audit: LocalAuditLogRepository());
  }

  static Future<_Fixture> seeded() async {
    final value = await empty();
    await value.products.restoreProductsIntoEmpty([_product]);
    await value.suppliers.restoreSuppliersIntoEmpty([_supplier]);
    await value.customers.restoreCustomersIntoEmpty([_customer]);
    final purchaseMovement = StockMovement(
        id: 'movement-purchase',
        productId: 'product-1',
        movementType: StockMovementType.purchaseIntake,
        quantityKg: 20,
        createdByUserId: 'owner',
        createdAt: _fixedDate);
    final saleMovement = StockMovement(
        id: 'movement-sale',
        productId: 'product-1',
        movementType: StockMovementType.sale,
        quantityKg: 5,
        createdByUserId: 'owner',
        createdAt: _fixedDate);
    await value.inventory
        .restoreMovementsIntoEmpty([purchaseMovement, saleMovement]);
    await value.financialAccounts.restoreFinancialAccountsIntoEmpty(
        accounts: [_account], entries: const []);
    await value.purchases.restorePurchaseIntakesIntoEmpty([
      PurchaseIntake(
          id: 'purchase-1',
          supplierId: _supplier.id,
          productId: _product.id,
          quantityKg: 20,
          entryUnit: GrainUnit.kilogram,
          unitPricePiastersPerKg: 100,
          totalAmountPiasters: 2000,
          createdByUserId: _owner.id,
          createdAt: _now,
          stockMovementId: purchaseMovement.id,
          financialAccountId: _account.id,
          paymentMethod: PaymentMethod.bankTransfer)
    ]);
    await value.sales.restoreSalesIntoEmpty([
      SaleRecord(
          id: 'sale-1',
          productId: _product.id,
          quantityKg: 5,
          salePriceQirshPerKg: 200,
          totalQirsh: 1000,
          createdByUserId: _owner.id,
          createdAt: _now,
          stockMovementId: saleMovement.id,
          customerId: _customer.id,
          financialAccountId: _account.id,
          paymentMethod: PaymentMethod.cash)
    ]);
    await value.customerAccounts
        .restoreCustomerAccountsIntoEmpty(entries: const [], collections: [
      CustomerCollectionRecord(
          id: 'collection-1',
          customerId: _customer.id,
          date: _now,
          amountQirsh: 300,
          createdAt: _now,
          createdByUserId: _owner.id,
          financialAccountId: _account.id,
          paymentMethod: PaymentMethod.mobileWallet)
    ]);
    await value.supplierAccounts
        .restoreSupplierAccountsIntoEmpty(entries: const [], payments: [
      SupplierPaymentRecord(
          id: 'payment-1',
          supplierId: _supplier.id,
          date: _now,
          amountQirsh: 400,
          createdAt: _now,
          createdByUserId: _owner.id,
          financialAccountId: _account.id,
          paymentMethod: PaymentMethod.check)
    ]);
    await value.expenses.restoreExpensesIntoEmpty([
      ExpenseRecord(
          id: 'expense-1',
          date: _now,
          category: 'Transport',
          amountQirsh: 100,
          createdAt: _now,
          financialAccountId: _account.id,
          paymentMethod: PaymentMethod.cash)
    ]);
    return value;
  }

  BackupExportService get exportService => BackupExportService(
      productRepository: products,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: history,
      customerRepository: customers,
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      auditLogRepository: audit,
      financialAccountRepository: financialAccounts,
      now: () => _now);

  BackupRestoreService get restoreService => BackupRestoreService(
      productRepository: products,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: history,
      customerRepository: customers,
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      auditLogRepository: audit,
      financialAccountRepository: financialAccounts);
}

final _fixedDate = DateTime.utc(2026, 7, 11);
