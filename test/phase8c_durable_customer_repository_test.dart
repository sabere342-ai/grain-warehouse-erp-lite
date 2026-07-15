import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// sqlite3 is used only to create an authentic schema-v2 migration fixture.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const _draft = CustomerDraft(name: 'Ahmed', phone: '0100', notes: 'note');

void main() {
  test('v2 migrates to v3 preserving probes, products and product sequence',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8c-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final legacy = sqlite3.open(file.path);
    legacy.execute(
        'CREATE TABLE foundation_probes (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
    legacy.execute('''CREATE TABLE products (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      normalized_name TEXT NOT NULL UNIQUE, code TEXT,
      normalized_code TEXT UNIQUE, unit TEXT NOT NULL,
      is_active INTEGER NOT NULL, default_sale_price_piasters_per_kg INTEGER,
      minimum_sale_price_piasters_per_kg INTEGER,
      reference_cost_price_piasters_per_kg INTEGER, notes TEXT,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
    legacy.execute('''CREATE TABLE repository_sequences (
      repository TEXT NOT NULL PRIMARY KEY, next_value INTEGER NOT NULL)''');
    legacy.execute("INSERT INTO foundation_probes VALUES ('legacy', 'kept')");
    legacy.execute('''INSERT INTO products VALUES
      ('prd-1-7', 'Wheat', 'wheat', 'WH', 'wh', 'ton', 1,
       NULL, NULL, NULL, NULL, 1, 1)''');
    legacy.execute("INSERT INTO repository_sequences VALUES ('products', 8)");
    legacy.execute('PRAGMA user_version = 2');
    legacy.dispose();

    var database = openDatabaseFile(file);
    expect(await database.readProbe('legacy'), 'kept');
    expect(await DriftProductRepository(database).listProducts(), hasLength(1));
    final customer =
        await DriftCustomerRepository(database).createCustomer(_draft);
    final product = await DriftProductRepository(database).createProduct(
        const ProductDraft(name: 'Corn', unit: GrainUnit.kilogram));
    expect(product.id, endsWith('-8'));
    await database.close();

    database = openDatabaseFile(file);
    expect(await DriftCustomerRepository(database).listCustomers(),
        contains(predicate<Customer>((value) => value.id == customer.id)));
    expect(await DriftProductRepository(database).listProducts(), hasLength(2));
    await database.close();
  });

  test('create, update, disable and ordering survive file-backed reopen',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8c-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = DriftCustomerRepository(database);
    final first = await repository.createCustomer(_draft);
    await repository.createCustomer(const CustomerDraft(name: 'Mona'));
    await repository.updateCustomer(
        customerId: first.id,
        draft: const CustomerDraft(name: 'Ahmed Ali', phone: '0111'));
    await repository.setCustomerActive(customerId: first.id, isActive: false);
    await database.close();

    database = openDatabaseFile(file);
    repository = DriftCustomerRepository(database);
    final all = await repository.listCustomers();
    expect(all.map((customer) => customer.name), ['Ahmed Ali', 'Mona']);
    expect(
        await repository.listCustomers(includeInactive: false), hasLength(1));
    await database.close();
  });

  test('local and Drift implementations share validation and duplicate rules',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    for (final repository in <CustomerRepository>[
      LocalCustomerRepository(),
      DriftCustomerRepository(database),
    ]) {
      await expectLater(
          repository.createCustomer(const CustomerDraft(name: '  ')),
          throwsArgumentError);
      await repository.createCustomer(_draft);
      await expectLater(
          repository.createCustomer(const CustomerDraft(name: ' ahmed ')),
          throwsStateError);
      await expectLater(
          repository.createCustomer(
              const CustomerDraft(name: 'Other', phone: ' 0100 ')),
          throwsStateError);
      await expectLater(
          repository.updateCustomer(
              customerId: 'missing', draft: const CustomerDraft(name: 'X')),
          throwsStateError);
    }
  });

  test('customer and product sequences are durable and independent', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final customers = DriftCustomerRepository(database);
    final products = DriftProductRepository(database);
    final customer = await customers.createCustomer(_draft);
    final product = await products
        .createProduct(const ProductDraft(name: 'Wheat', unit: GrainUnit.ton));
    expect(customer.id, endsWith('-1'));
    expect(product.id, endsWith('-1'));
  });

  test('production initialization wires DriftCustomerRepository', () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.customerRepository, isA<DriftCustomerRepository>());
    await AppRepositories.close();
  });

  test('failed repository transaction restores customers and sequence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftCustomerRepository(database);
    await expectLater(
      RepositoryTransaction.execute([repository.createTransactionSnapshot()],
          () async {
        await repository.createCustomer(_draft);
        throw const FormatException('injected');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(await repository.listCustomers(), isEmpty);
    expect((await repository.createCustomer(_draft)).id, endsWith('-1'));
  });

  test('concurrent creates allocate unique durable ids', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftCustomerRepository(database);
    final customers = await Future.wait(List.generate(
        20,
        (index) => repository.createCustomer(
            CustomerDraft(name: 'Customer $index', phone: '010$index'))));
    expect(customers.map((customer) => customer.id).toSet(), hasLength(20));
    expect(await repository.listCustomers(), hasLength(20));
  });

  test('owner wipe and restore preserve rows and advance the next id',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftCustomerRepository(database);
    final original = await repository.createCustomer(_draft);
    final snapshot = await repository.listCustomers();
    await repository.clearForOwnerDataWipe();
    expect(await repository.listCustomers(), isEmpty);
    await repository.restoreCustomersIntoEmpty(snapshot);
    final next = await repository
        .createCustomer(const CustomerDraft(name: 'Next customer'));
    expect(next.id, isNot(original.id));
    expect(next.id, endsWith('-2'));
  });
}
