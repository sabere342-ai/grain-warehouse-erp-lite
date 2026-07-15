import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// sqlite3 is supplied transitively by Drift and is used only to build an
// authentic legacy v1 fixture before the application database opens it.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

const _draft = ProductDraft(name: 'Wheat', code: 'WH', unit: GrainUnit.ton);

void main() {
  test('v1 migrates to v2 without losing foundation probes', () async {
    final directory =
        await Directory.systemTemp.createTemp('phase8b-migration-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final legacy = sqlite3.open(file.path);
    legacy.execute(
        'CREATE TABLE foundation_probes (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
    legacy.execute("INSERT INTO foundation_probes VALUES ('legacy', 'kept')");
    legacy.execute('PRAGMA user_version = 1');
    legacy.dispose();

    var database = openDatabaseFile(file);
    expect(await database.readProbe('legacy'), 'kept');
    final repository = DriftProductRepository(database);
    expect((await repository.createProduct(_draft)).name, 'Wheat');
    await database.close();

    database = openDatabaseFile(file);
    expect(await database.readProbe('legacy'), 'kept');
    expect(await DriftProductRepository(database).listProducts(), hasLength(1));
    await database.close();
  });

  test('create survives reopen and durable ids are not reused after delete',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8b-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    final first = await DriftProductRepository(database).createProduct(_draft);
    await database.close();
    database = openDatabaseFile(file);
    final repository = DriftProductRepository(database);
    final second = await repository.createProduct(
        const ProductDraft(name: 'Corn', unit: GrainUnit.kilogram));
    expect(second.id, isNot(first.id));
    expect(await repository.listProducts(), hasLength(2));
    await database.close();
  });

  test('failed repository transaction restores products and sequence',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftProductRepository(database);
    await expectLater(
      RepositoryTransaction.execute([repository.createTransactionSnapshot()],
          () async {
        await repository.createProduct(_draft);
        throw const FormatException('injected');
      }),
      throwsA(isA<FormatException>()),
    );
    expect(await repository.listProducts(), isEmpty);
    final created = await repository.createProduct(_draft);
    expect(created.id, endsWith('-1'));
  });

  test('concurrent creates serialize with unique durable ids', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftProductRepository(database);
    final products = await Future.wait(List.generate(
        20,
        (i) => repository.createProduct(
              ProductDraft(
                  name: 'Product $i', code: 'P$i', unit: GrainUnit.kilogram),
            )));
    expect(products.map((p) => p.id).toSet(), hasLength(20));
    expect(await repository.listProducts(), hasLength(20));
  });

  test(
      'update, active filtering, uniqueness, wipe and restore preserve contracts',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftProductRepository(database);
    final first = await repository.createProduct(_draft);
    await repository.createProduct(
        const ProductDraft(name: 'Corn', code: 'CO', unit: GrainUnit.kilogram));
    await expectLater(
        repository.updateProduct(
            productId: first.id,
            draft: const ProductDraft(name: ' corn ', unit: GrainUnit.ton)),
        throwsStateError);
    await repository.setProductActive(productId: first.id, isActive: false);
    expect(await repository.listProducts(includeInactive: false), hasLength(1));
    final snapshot = await repository.listProducts();
    await repository.clearForOwnerDataWipe();
    await repository.restoreProductsIntoEmpty(snapshot);
    expect(
        (await repository.listProducts()).map((p) => p.id), contains(first.id));
  });
}
