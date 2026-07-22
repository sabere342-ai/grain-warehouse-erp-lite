import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
// sqlite3 is used only to create an authentic schema-v3 migration fixture.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const _draft = SupplierDraft(
  name: 'Ahmed',
  phone: '0100',
  address: 'Cairo',
  notes: 'note',
);

void main() {
  test('durable supplier revisions advance beyond restored timestamps',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftSupplierRepository(database);
    final future = DateTime.now().add(const Duration(days: 1));
    await repository.restoreSuppliersIntoEmpty([
      Supplier(
        id: 'sup-restored-1',
        name: 'Restored supplier',
        isActive: true,
        createdAt: future.subtract(const Duration(days: 2)),
        updatedAt: future,
      ),
    ]);

    final updated = await repository.updateSupplier(
      supplierId: 'sup-restored-1',
      draft: const SupplierDraft(name: 'Updated restored supplier'),
    );

    expect(updated.updatedAt.isAfter(future), isTrue);
  });

  test('v3 migrates to v4 preserving prior tables, rows and sequences',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8d-migrate-');
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
    legacy.execute('''CREATE TABLE customers (
      id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      normalized_name TEXT NOT NULL UNIQUE, phone TEXT,
      normalized_phone TEXT UNIQUE, notes TEXT, is_active INTEGER NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
    legacy.execute("INSERT INTO foundation_probes VALUES ('legacy', 'kept')");
    legacy.execute('''INSERT INTO customers VALUES
      ('cus-1-4', 'Mona', 'mona', NULL, NULL, NULL, 1, 1, 1)''');
    legacy.execute("INSERT INTO repository_sequences VALUES ('customers', 5)");
    legacy.execute('PRAGMA user_version = 3');
    legacy.dispose();

    final database = openDatabaseFile(file);
    expect(await database.readProbe('legacy'), 'kept');
    expect(
        await DriftCustomerRepository(database).listCustomers(), hasLength(1));
    final nextCustomer = await DriftCustomerRepository(database)
        .createCustomer(const CustomerDraft(name: 'Next'));
    expect(nextCustomer.id, endsWith('-5'));
    expect(await DriftProductRepository(database).listProducts(), isEmpty);
    expect(await DriftSupplierRepository(database).createSupplier(_draft),
        isA<Supplier>());
    await database.close();
  });

  test('CRUD, filtering and sequence survive file-backed reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase8d-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = DriftSupplierRepository(database);
    final first = await repository.createSupplier(_draft);
    await repository.createSupplier(const SupplierDraft(name: 'Mona'));
    await repository.updateSupplier(
        supplierId: first.id,
        draft: const SupplierDraft(name: 'Ahmed Ali', phone: '0111'));
    await repository.setSupplierActive(supplierId: first.id, isActive: false);
    await database.close();

    database = openDatabaseFile(file);
    repository = DriftSupplierRepository(database);
    expect((await repository.listSuppliers()).map((value) => value.name),
        ['Ahmed Ali', 'Mona']);
    expect(
        await repository.listSuppliers(includeInactive: false), hasLength(1));
    final third = await repository
        .createSupplier(const SupplierDraft(name: 'Third supplier'));
    expect(third.id, endsWith('-3'));
    await database.close();
  });

  test('local and Drift implementations share validation and duplicate rules',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    for (final repository in <SupplierRepository>[
      LocalSupplierRepository(),
      DriftSupplierRepository(database),
    ]) {
      await expectLater(
          repository.createSupplier(const SupplierDraft(name: '  ')),
          throwsArgumentError);
      await repository.createSupplier(_draft);
      await expectLater(
          repository.createSupplier(const SupplierDraft(name: ' ahmed ')),
          throwsStateError);
      await expectLater(
          repository.createSupplier(
              const SupplierDraft(name: 'Other', phone: ' 0100 ')),
          throwsStateError);
      await expectLater(
          repository.updateSupplier(
              supplierId: 'missing', draft: const SupplierDraft(name: 'Other')),
          throwsStateError);
    }
  });

  test('failed repository transaction restores suppliers and sequence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftSupplierRepository(database);
    await expectLater(
      RepositoryTransaction.execute([repository.createTransactionSnapshot()],
          () async {
        await repository.createSupplier(_draft);
        throw const FormatException('injected');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(await repository.listSuppliers(), isEmpty);
    expect((await repository.createSupplier(_draft)).id, endsWith('-1'));
  });

  test('concurrent creates allocate unique durable ids', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftSupplierRepository(database);
    final suppliers = await Future.wait(List.generate(
        20,
        (index) => repository.createSupplier(
            SupplierDraft(name: 'Supplier $index', phone: '010$index'))));
    expect(suppliers.map((value) => value.id).toSet(), hasLength(20));
  });

  test('owner wipe and restore preserve rows and advance the next id',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftSupplierRepository(database);
    final original = await repository.createSupplier(_draft);
    final snapshot = await repository.listSuppliers();
    await repository.clearForOwnerDataWipe();
    await repository.restoreSuppliersIntoEmpty(snapshot);
    final next = await repository
        .createSupplier(const SupplierDraft(name: 'Next supplier'));
    expect(next.id, isNot(original.id));
    expect(next.id, endsWith('-2'));
  });

  test('separate test databases are isolated', () async {
    final directory = await Directory.systemTemp.createTemp('phase8d-isolate-');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final first = openDatabaseFile(
        File('${directory.path}${Platform.pathSeparator}first.sqlite3'));
    await DriftSupplierRepository(first).createSupplier(_draft);
    await first.close();
    final second = openDatabaseFile(
        File('${directory.path}${Platform.pathSeparator}second.sqlite3'));
    expect(await DriftSupplierRepository(second).listSuppliers(), isEmpty);
    await second.close();
  });

  test('production initialization wires DriftSupplierRepository', () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.supplierRepository, isA<DriftSupplierRepository>());
    await AppRepositories.close();
  });
}
